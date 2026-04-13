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
    "SDP_product_table_04_11_2023.csv"
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
    """Parse M/D/YYYY date strings from the catalog CSV."""
    if not s or s.strip() == "":
        return None
    try:
        return datetime.strptime(s.strip(), "%m/%d/%Y").date()
    except ValueError:
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
                "MinDate": _parse_date(raw.get("MinDate", "")),
                "MaxDate": _parse_date(raw.get("MaxDate", "")),
                "MinYear": _safe_int(raw.get("MinYear", "")),
                "MaxYear": _safe_int(raw.get("MaxYear", "")),
                "TimeSeriesType": raw.get("TimeSeriesType", "").strip(),
                "DataType": raw.get("DataType", "").strip(),
                "DataUnit": raw.get("DataUnit", "").strip(),
                "DataScaleFactor": _safe_float(
                    raw.get("DataScaleFactor", "")
                ),
                "DataOffset": _safe_float(raw.get("DataOffset", "")),
                "Data.URL": raw.get("Data.URL", "").strip(),
                "Metadata.URL": raw.get("Metadata.URL", "").strip(),
            }
        )
    return rows


def load_catalog(
    url: str = DEFAULT_CATALOG_URL,
    use_cache: bool = True,
) -> tuple[list[dict], str]:
    """Fetch and parse the catalog. Returns (rows, source_filename)."""
    csv_text = fetch_catalog_csv(url, use_cache=use_cache)
    rows = parse_catalog(csv_text)
    source_filename = url.rsplit("/", 1)[-1]
    return rows, source_filename
