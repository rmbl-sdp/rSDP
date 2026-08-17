"""Download and parse the canonical SDP product catalog CSV."""

import csv
import hashlib
import io
import os
from datetime import date, datetime
from pathlib import Path

import requests

# Same URL as data-raw/SDP_catalog.R uses — canonical source.
DEFAULT_CATALOG_URL = (
    "https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/"
    "SDP_product_table_08_17_2026.csv"
)

CACHE_DIR = Path(__file__).resolve().parent.parent / ".cache"


def fetch_catalog_csv(
    url: str = DEFAULT_CATALOG_URL,
    use_cache: bool = True,
) -> str:
    """Fetch the catalog CSV text, optionally caching to disk."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_key = hashlib.sha256(url.encode()).hexdigest()[:12]
    cache_path = CACHE_DIR / f"catalog_{cache_key}.csv"

    if use_cache and cache_path.exists():
        return cache_path.read_text()

    resp = requests.get(url, timeout=60)
    resp.raise_for_status()
    text = resp.text
    cache_path.write_text(text)
    return text


def _parse_date(s: str) -> date | None:
    """Parse date strings from the catalog CSV.

    Handles both 4-digit year (M/D/YYYY) and 2-digit year (M/D/YY)
    formats, since the upstream CSV has used both over time.
    """
    if not s or s.strip() == "":
        return None
    s = s.strip()
    for fmt in ("%m/%d/%Y", "%m/%d/%y"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


def _safe_int(s: str) -> int | None:
    try:
        return int(s)
    except (ValueError, TypeError):
        return None


def _safe_float(s: str) -> float | None:
    try:
        return float(s)
    except (ValueError, TypeError):
        return None


def _parse_resolution(s: str) -> float | None:
    """Parse a resolution string like '1m', '27m', '5cm', '0.333m' to meters."""
    if not s or not s.strip():
        return None
    s = s.strip().lower()
    if s.endswith("cm"):
        val = _safe_float(s[:-2])
        return val / 100.0 if val is not None else None
    if s.endswith("m"):
        return _safe_float(s[:-1])
    return _safe_float(s)


def parse_catalog(csv_text: str) -> list[dict]:
    """Parse catalog CSV text into a list of row dicts with typed fields."""
    reader = csv.DictReader(io.StringIO(csv_text))
    rows = []
    for raw in reader:
        rows.append(
            {
                "CatalogID": raw["CatalogID"].strip(),
                "Release": raw["Release"].strip(),
                "Type": raw["Type"].strip(),
                "Product": raw["Product"].strip(),
                "Domain": raw["Domain"].strip(),
                "Resolution": _parse_resolution(raw.get("Resolution", "")),
                "Deprecated": raw.get("Deprecated", "").strip().upper() == "TRUE",
                "NewVersionID": raw.get("NewVersionID", "").strip() or None,
                "MinDate": _parse_date(raw.get("MinDate", "")),
                "MaxDate": _parse_date(raw.get("MaxDate", "")),
                "MinYear": _safe_int(raw.get("MinYear", "")),
                "MaxYear": _safe_int(raw.get("MaxYear", "")),
                "TimeSeriesType": raw.get("TimeSeriesType", "").strip(),
                "TimeSeriesRegularity": raw.get("TimeSeriesRegularity", "").strip(),
                "DataType": raw.get("DataType", "").strip(),
                "DataUnit": raw.get("DataUnit", "").strip(),
                "DataScaleFactor": _safe_float(
                    raw.get("DataScaleFactor", "")
                ),
                "DataOffset": _safe_float(raw.get("DataOffset", "")),
                "Data.URL": raw.get("Data.URL", "").strip(),
                "Metadata.URL": raw.get("Metadata.URL", "").strip(),
                "ColorRampDefault": raw.get("ColorRampDefault", "").strip(),
            }
        )
    return rows


# Catalog rows must carry these URL fields. Without them the STAC builder
# cannot resolve COG paths (Data.URL) or parse license/title (Metadata.URL),
# and downstream consumers silently fall back to broken defaults
# (license="proprietary", missing thumbnails). Fail loudly at load time
# rather than shipping a half-broken catalog.
REQUIRED_URL_FIELDS = ("Data.URL", "Metadata.URL")


def validate_required_fields(rows: list[dict]) -> None:
    """Raise ValueError if any row is missing a required URL field."""
    missing: dict[str, list[str]] = {}
    for row in rows:
        for field in REQUIRED_URL_FIELDS:
            value = row.get(field)
            if value is None or not str(value).strip():
                missing.setdefault(field, []).append(row.get("CatalogID", "?"))
    if missing:
        parts = [f"{f} (rows: {', '.join(ids)})" for f, ids in sorted(missing.items())]
        raise ValueError(
            "Catalog is missing required URL fields:\n  " + "\n  ".join(parts)
        )


def validate_unique_catalog_ids(rows: list[dict]) -> None:
    """Raise ValueError if any CatalogID appears more than once.

    A fill-down slip in the source spreadsheet once published a table with
    three rows sharing one CatalogID, silently shadowing two products and
    dangling the NewVersionID references that pointed at them.
    """
    seen: dict[str, int] = {}
    for row in rows:
        cat_id = str(row.get("CatalogID", "")).strip()
        seen[cat_id] = seen.get(cat_id, 0) + 1
    dups = sorted(cid for cid, n in seen.items() if n > 1)
    if dups:
        raise ValueError(f"Duplicate CatalogIDs in catalog: {', '.join(dups)}")


def load_catalog(
    url: str = DEFAULT_CATALOG_URL,
    use_cache: bool = True,
) -> tuple[list[dict], str]:
    """Fetch and parse the catalog. Returns (rows, source_filename)."""
    csv_text = fetch_catalog_csv(url, use_cache=use_cache)
    rows = parse_catalog(csv_text)
    validate_required_fields(rows)
    validate_unique_catalog_ids(rows)
    source_filename = url.rsplit("/", 1)[-1]
    return rows, source_filename
