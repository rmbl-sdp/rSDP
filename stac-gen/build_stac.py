#!/usr/bin/env python3
"""Build a static STAC catalog for the RMBL Spatial Data Platform.

Reads the canonical SDP product catalog CSV, fetches per-dataset XML
metadata and COG headers, and writes a static STAC tree to disk. The
output is designed for hosting on S3 under /stac/v1/.

Usage:
    python build_stac.py --output-dir out/stac/v1
    python build_stac.py --help
"""

import argparse
import logging
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from itertools import groupby
from pathlib import Path

import pystac

from lib.catalog_loader import load_catalog
from lib.cog_probe import probe_cog
from lib.metadata_parser import fetch_metadata
from lib.slugs import check_slug_collisions, product_to_slug
from lib.stac_builder import (
    build_collection,
    build_domain_catalog,
    build_item,
    build_root_catalog,
)
from lib.time_resolver import resolve_time_slices

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("out/stac/v1"),
        help="Output directory for the STAC tree (default: out/stac/v1)",
    )
    parser.add_argument(
        "--max-workers",
        type=int,
        default=20,
        help="Max parallel workers for metadata/COG fetches (default: 20)",
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable caching of remote fetches",
    )
    args = parser.parse_args()
    use_cache = not args.no_cache

    # --- Step 1: Load catalog ---
    log.info("Loading catalog CSV...")
    rows, source_filename = load_catalog(use_cache=use_cache)
    log.info("Loaded %d catalog rows from %s", len(rows), source_filename)

    # --- Check for slug collisions ---
    all_products = [r["Product"] for r in rows]
    collisions = check_slug_collisions(all_products)
    if collisions:
        log.warning("Slug collisions detected: %s", collisions)
        # Collisions within the same domain would produce duplicate
        # collection paths. Cross-domain collisions are OK because
        # collections live under domain sub-catalogs.

    # --- Step 2: Pre-fetch metadata and COG headers in parallel ---
    # Group rows by CatalogID to avoid duplicate fetches for the same
    # product (CatalogID is unique per product).
    unique_rows = {r["CatalogID"]: r for r in rows}

    log.info(
        "Fetching metadata and COG headers for %d products "
        "(max %d workers)...",
        len(unique_rows),
        args.max_workers,
    )
    metadata_cache: dict[str, dict] = {}
    cog_cache: dict[str, dict] = {}

    def _fetch_product_info(cat_id: str, row: dict):
        """Fetch metadata XML + one COG header for a product."""
        meta = {}
        cog = {}
        # Metadata XML
        meta_url = row.get("Metadata.URL")
        if meta_url:
            meta = fetch_metadata(meta_url, use_cache=use_cache)
        # COG header from a representative file
        data_url = row["Data.URL"]
        ts_type = row["TimeSeriesType"]
        # For time series, resolve the first slice to get a concrete URL.
        if ts_type != "Single" and row.get("MinYear"):
            first_url = _resolve_first_url(row)
        else:
            first_url = data_url
        if first_url:
            try:
                cog = probe_cog(first_url, cat_id, use_cache=use_cache)
            except Exception as exc:
                log.warning(
                    "Failed to read COG header for %s (%s): %s",
                    cat_id,
                    first_url,
                    exc,
                )
        return cat_id, meta, cog

    with ThreadPoolExecutor(max_workers=args.max_workers) as executor:
        futures = {
            executor.submit(_fetch_product_info, cid, r): cid
            for cid, r in unique_rows.items()
        }
        for future in as_completed(futures):
            cat_id = futures[future]
            try:
                cid, meta, cog = future.result()
                metadata_cache[cid] = meta
                cog_cache[cid] = cog
            except Exception as exc:
                log.error("Error fetching info for %s: %s", cat_id, exc)

    log.info("Pre-fetch complete.")

    # --- Step 3: Build the STAC tree ---
    root = build_root_catalog(source_filename)

    # Group rows by Domain.
    rows_sorted = sorted(rows, key=lambda r: r["Domain"])
    for domain, domain_rows in groupby(rows_sorted, key=lambda r: r["Domain"]):
        domain_cat = build_domain_catalog(domain)
        domain_rows_list = list(domain_rows)

        for row in domain_rows_list:
            cat_id = row["CatalogID"]
            meta = metadata_cache.get(cat_id, {})
            cog = cog_cache.get(cat_id, {})
            slices = resolve_time_slices(row)

            collection = build_collection(row, meta, cog, slices)

            for start_date, end_date, resolved_url in slices:
                item = build_item(
                    row, start_date, end_date, resolved_url, cog, meta
                )
                collection.add_item(item)

            domain_cat.add_child(collection)

        root.add_child(domain_cat)

    # --- Step 4: Write to disk ---
    output_dir = args.output_dir
    log.info("Writing STAC tree to %s...", output_dir)
    root.normalize_hrefs(str(output_dir))
    root.save(
        catalog_type=pystac.CatalogType.SELF_CONTAINED,
        dest_href=str(output_dir),
    )

    # Count outputs.
    json_count = len(list(output_dir.rglob("*.json")))
    log.info("Done. Wrote %d JSON files to %s", json_count, output_dir)


def _resolve_first_url(row: dict) -> str | None:
    """Resolve the template to the first time slice URL for COG probing."""
    template = row["Data.URL"]
    ts_type = row["TimeSeriesType"]

    if ts_type == "Yearly" and row.get("MinYear"):
        return template.replace("{year}", str(row["MinYear"]))

    if ts_type == "Monthly" and row.get("MinDate"):
        d = row["MinDate"]
        return (
            template.replace("{year}", str(d.year))
            .replace("{month}", f"{d.month:02d}")
        )

    if ts_type == "Daily" and row.get("MinDate"):
        d = row["MinDate"]
        doy = d.strftime("%j")
        return (
            template.replace("{year}", str(d.year))
            .replace("{day}", doy)
        )

    return None


if __name__ == "__main__":
    main()
