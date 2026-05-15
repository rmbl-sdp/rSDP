"""Helpers for reading SDP data-issue counts from the GitHub Issues API.

Counts are surfaced into STAC collections as `rmbl:open_issues_count`
and used to wire a `report-issue` rel link on every collection. Both
the full STAC build (build_stac.py) and the patch-in-place refresh
(refresh_issue_counts.py) use this module so the two pipelines stay
consistent.
"""

from __future__ import annotations

import logging
import os
import urllib.parse
from collections import Counter

import requests

log = logging.getLogger(__name__)

ISSUES_REPO_DEFAULT = "rmbl-sdp/sdp-products"
ISSUES_HTML_BASE = "https://github.com/{repo}"
ISSUES_API_BASE = "https://api.github.com/repos/{repo}"
ISSUES_PRODUCT_PREFIX = "product:"


def fetch_open_issue_counts(
    repo: str = ISSUES_REPO_DEFAULT,
    token: str | None = None,
) -> dict[str, int]:
    """Return a {CatalogID: open_issues_count} map.

    Fetches all open issues from the given repo, groups by the
    `product:<CATID>` label, and counts. Pull requests (which the GH
    API lumps into the same endpoint) are filtered out.

    On any HTTP error, logs a warning and returns an empty dict — the
    builder/patch script should still produce a valid STAC even if the
    GitHub API is temporarily unavailable.
    """
    token = token or os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "rmbl-sdp-stac-gen",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    counts: Counter[str] = Counter()
    page = 1
    per_page = 100
    while True:
        url = (
            f"{ISSUES_API_BASE.format(repo=repo)}/issues"
            f"?state=open&per_page={per_page}&page={page}"
        )
        try:
            resp = requests.get(url, headers=headers, timeout=30)
            resp.raise_for_status()
        except requests.RequestException as exc:
            log.warning("Could not fetch issue counts from %s: %s", repo, exc)
            return {}

        chunk = resp.json()
        if not chunk:
            break
        for issue in chunk:
            if "pull_request" in issue:
                continue
            for label in issue.get("labels", []):
                name = label.get("name", "")
                if name.startswith(ISSUES_PRODUCT_PREFIX):
                    counts[name[len(ISSUES_PRODUCT_PREFIX):]] += 1
                    break
        if len(chunk) < per_page:
            break
        page += 1

    return dict(counts)


def report_issue_url(catalog_id: str, repo: str = ISSUES_REPO_DEFAULT) -> str:
    """Construct the prefilled GitHub Issue Form URL for a CatalogID."""
    qs = urllib.parse.urlencode(
        {"template": "dataset-issue.yml", "catalog_id": catalog_id}
    )
    return f"{ISSUES_HTML_BASE.format(repo=repo)}/issues/new?{qs}"


def issues_search_url(catalog_id: str, repo: str = ISSUES_REPO_DEFAULT) -> str:
    """Construct the filtered open-issues list URL for a CatalogID."""
    q = f"is:issue is:open label:product:{catalog_id}"
    return (
        f"{ISSUES_HTML_BASE.format(repo=repo)}/issues?"
        + urllib.parse.urlencode({"q": q})
    )
