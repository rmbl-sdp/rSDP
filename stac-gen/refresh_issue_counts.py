#!/usr/bin/env python3
"""Patch `rmbl:open_issues_count` on STAC collection.json files in place.

Used by the refresh workflow on rmbl-sdp/sdp-products to keep the STAC
catalog's per-collection issue count fresh without rebuilding the full
catalog (which would touch ~32K item JSONs to refresh ~164 numbers).

Workflow:
    1. (caller) aws s3 sync <bucket>/stac/v1/ <local>/ --include "*/collection.json"
    2. python refresh_issue_counts.py --stac-dir <local>
    3. (caller) aws s3 sync <local>/ <bucket>/stac/v1/ --include "*/collection.json"

The script reads `rmbl:catalog_id` from each `collection.json` to map
it to a CatalogID, then writes the new count (and ensures the
`report-issue` link is present, in case the collection predates that
feature). Only files whose content actually changes get re-serialized,
so the S3 sync diff stays small.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path

from lib.issues import (
    ISSUES_REPO_DEFAULT,
    fetch_open_issue_counts,
    issues_search_url,
    report_issue_url,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("refresh_issue_counts")


def patch_collection(path: Path, counts: dict[str, int]) -> bool:
    """Patch a single collection.json. Returns True if the file changed."""
    try:
        original_text = path.read_text()
        coll = json.loads(original_text)
    except (OSError, json.JSONDecodeError) as exc:
        log.warning("Skipping %s: %s", path, exc)
        return False

    cat_id = coll.get("rmbl:catalog_id")
    if not cat_id:
        return False

    new_count = int(counts.get(cat_id, 0))
    coll["rmbl:open_issues_count"] = new_count

    # Refresh the report-issue and related links. We replace rather than
    # only-add-if-missing so that an upstream repo rename (or any other
    # URL drift) gets corrected by the next refresh run. Other rel links
    # (root, parent, item, successor-version, ...) are untouched.
    expected_report = report_issue_url(cat_id)
    expected_related = issues_search_url(cat_id)
    new_links = []
    seen_report = seen_related = False
    for link in coll.get("links", []):
        rel = link.get("rel")
        href = link.get("href") or ""
        if rel == "report-issue":
            seen_report = True
            new_links.append({
                "rel": "report-issue",
                "href": expected_report,
                "title": "Report an issue with this dataset",
            })
        elif rel == "related" and "issues?" in href:
            seen_related = True
            new_links.append({
                "rel": "related",
                "href": expected_related,
                "title": "Open issues for this dataset",
            })
        else:
            new_links.append(link)
    if not seen_report:
        new_links.append({
            "rel": "report-issue",
            "href": expected_report,
            "title": "Report an issue with this dataset",
        })
    if not seen_related:
        new_links.append({
            "rel": "related",
            "href": expected_related,
            "title": "Open issues for this dataset",
        })
    coll["links"] = new_links

    new_text = json.dumps(coll, indent=2, sort_keys=False) + "\n"
    if new_text == original_text:
        return False

    path.write_text(new_text)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--stac-dir",
        type=Path,
        required=True,
        help="Local directory containing the STAC tree (expects */collection.json).",
    )
    parser.add_argument(
        "--issues-repo",
        default=ISSUES_REPO_DEFAULT,
        help=f"GitHub repo to read issues from (default: {ISSUES_REPO_DEFAULT}).",
    )
    args = parser.parse_args()

    if not args.stac_dir.is_dir():
        log.error("STAC dir not found: %s", args.stac_dir)
        return 1

    log.info("Fetching open issue counts from %s...", args.issues_repo)
    counts = fetch_open_issue_counts(repo=args.issues_repo)
    log.info("Got counts for %d products", len(counts))

    collections = sorted(args.stac_dir.rglob("*/collection.json"))
    log.info("Scanning %d collection.json files...", len(collections))

    changed = 0
    for path in collections:
        if patch_collection(path, counts):
            changed += 1
            log.info("  patched %s", path.relative_to(args.stac_dir))

    log.info("Done. %d collection file(s) changed; %d unchanged.",
             changed, len(collections) - changed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
