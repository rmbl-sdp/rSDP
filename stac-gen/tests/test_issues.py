import urllib.parse
from unittest.mock import MagicMock, patch

from lib.issues import (
    ISSUES_REPO_DEFAULT,
    fetch_open_issue_counts,
    issues_search_url,
    report_issue_url,
)


def test_report_issue_url_encodes_catalog_id():
    url = report_issue_url("R4D001")
    assert url.startswith("https://github.com/rmbl-sdp/sdp-products/issues/new?")
    qs = urllib.parse.parse_qs(url.split("?", 1)[1])
    assert qs["template"] == ["dataset-issue.yml"]
    assert qs["catalog_id"] == ["R4D001"]


def test_issues_search_url_filters_by_product_label():
    url = issues_search_url("R6D007")
    assert "product:R6D007" in urllib.parse.unquote(url)
    assert "is:issue" in urllib.parse.unquote(url)
    assert "is:open" in urllib.parse.unquote(url)


def test_fetch_open_issue_counts_groups_by_product_label():
    fake_response = MagicMock()
    fake_response.json.return_value = [
        {"labels": [{"name": "product:R4D001"}, {"name": "type:incorrect-values"}]},
        {"labels": [{"name": "product:R4D001"}]},
        {"labels": [{"name": "product:R4D008"}]},
        # PR — should be ignored.
        {"pull_request": {"url": "x"}, "labels": [{"name": "product:R3D009"}]},
        # No product label — should be skipped silently.
        {"labels": [{"name": "type:other"}]},
    ]
    fake_response.raise_for_status.return_value = None
    with patch("lib.issues.requests.get", return_value=fake_response):
        counts = fetch_open_issue_counts()
    assert counts == {"R4D001": 2, "R4D008": 1}


def test_fetch_open_issue_counts_returns_empty_on_network_error():
    import requests
    with patch(
        "lib.issues.requests.get",
        side_effect=requests.RequestException("offline"),
    ):
        counts = fetch_open_issue_counts()
    assert counts == {}


def test_default_repo_constant():
    assert ISSUES_REPO_DEFAULT == "rmbl-sdp/sdp-products"
