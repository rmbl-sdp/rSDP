"""Fetch and parse per-dataset QGIS XML metadata files.

The XML structure (based on exploration in the 2026-04-09 session):

    <qgis>
      <identifier>...</identifier>
      <title>...</title>
      <abstract>...</abstract>
      <keywords><keyword>Environment</keyword>...</keywords>
      <license>Creative Commons Attribution 4.0</license>
      <crs><spatialrefsys><authid>EPSG:32613</authid>...</spatialrefsys></crs>
      <extent>
        <spatial xmin=... xmax=... ymin=... ymax=... />
      </extent>
    </qgis>
"""

import hashlib
import json
from pathlib import Path

import requests
from lxml import etree

CACHE_DIR = Path(__file__).resolve().parent.parent / ".cache" / "metadata"

# Map common license strings from XML to SPDX identifiers.
LICENSE_MAP = {
    "Creative Commons Attribution 4.0": "CC-BY-4.0",
    "Creative Commons Attribution 4.0 International": "CC-BY-4.0",
    "Creative Commons Attribution Share-Alike 4.0": "CC-BY-SA-4.0",
    "Creative Commons Attribution-ShareAlike 4.0": "CC-BY-SA-4.0",
    "CC BY 4.0": "CC-BY-4.0",
    "CC BY-SA 4.0": "CC-BY-SA-4.0",
}


def fetch_metadata(
    metadata_url: str,
    use_cache: bool = True,
) -> dict:
    """Fetch and parse a QGIS XML metadata file into a STAC-ready dict.

    Returns a dict with keys:
        title, description, license_spdx, keywords, native_bbox,
        epsg_code
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_key = hashlib.sha256(metadata_url.encode()).hexdigest()[:12]
    cache_path = CACHE_DIR / f"{cache_key}.json"

    if use_cache and cache_path.exists():
        return json.loads(cache_path.read_text())

    try:
        resp = requests.get(metadata_url, timeout=60)
        resp.raise_for_status()
        result = _parse_qgis_xml(resp.content)
    except Exception as exc:
        result = {
            "title": None,
            "description": None,
            "license_spdx": "proprietary",
            "keywords": [],
            "native_bbox": None,
            "epsg_code": None,
            "_error": str(exc),
        }

    cache_path.write_text(json.dumps(result, indent=2))
    return result


def _parse_qgis_xml(xml_bytes: bytes) -> dict:
    """Extract STAC-relevant fields from QGIS metadata XML."""
    root = etree.fromstring(xml_bytes)

    title = _text(root, ".//title")
    abstract = _text(root, ".//abstract")
    license_raw = _text(root, ".//license") or ""
    license_spdx = LICENSE_MAP.get(license_raw.strip(), "proprietary")

    keywords = [
        kw.text.strip()
        for kw in root.findall(".//keyword")
        if kw.text and kw.text.strip()
    ]

    # Native bounding box from <extent><spatial>
    spatial = root.find(".//extent/spatial")
    if spatial is not None:
        native_bbox = [
            float(spatial.get("xmin", 0)),
            float(spatial.get("ymin", 0)),
            float(spatial.get("xmax", 0)),
            float(spatial.get("ymax", 0)),
        ]
    else:
        native_bbox = None

    epsg_code = _text(root, ".//crs/spatialrefsys/authid")

    return {
        "title": title,
        "description": abstract,
        "license_spdx": license_spdx,
        "keywords": keywords,
        "native_bbox": native_bbox,
        "epsg_code": epsg_code,
    }


def _text(root, xpath: str) -> str | None:
    """Extract text from the first matching element, or None."""
    el = root.find(xpath)
    if el is not None and el.text:
        return el.text.strip()
    return None
