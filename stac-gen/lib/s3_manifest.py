"""Build file manifests for irregular time-series by probing S3.

For products with TimeSeriesType="Weekly" and
TimeSeriesRegularity="Irregular", we cannot enumerate dates from a
formula — the actual acquisition dates vary. This module lists the
S3 directory to discover which files exist, parses dates from the
filenames, and returns a manifest of (date, url) tuples that the
time_resolver and STAC builder can consume.
"""

import json
import re
import subprocess
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

CACHE_DIR = Path(__file__).resolve().parent.parent / ".cache" / "manifests"


def build_manifest(row: dict, use_cache: bool = True) -> list[tuple[date, date, str]]:
    """Discover actual files on S3 for an irregular time-series product.

    Parameters
    ----------
    row : dict
        Parsed catalog row. Must have Data.URL with template placeholders
        and TimeSeriesType in ("Weekly",).
    use_cache : bool
        Cache the S3 listing to .cache/manifests/{CatalogID}.json.

    Returns
    -------
    list of (start_date, end_date, resolved_url)
        One entry per discovered file, compatible with time_resolver
        output format. For Weekly data, start_date == end_date (instant).
    """
    cat_id = row["CatalogID"]

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = CACHE_DIR / f"{cat_id}.json"

    if use_cache and cache_path.exists():
        cached = json.loads(cache_path.read_text())
        return [
            (date.fromisoformat(e["start"]), date.fromisoformat(e["end"]), e["url"])
            for e in cached
        ]

    template = row["Data.URL"]
    s3_prefix = _template_to_s3_prefix(template)
    if not s3_prefix:
        return []

    tif_keys = _list_s3_tifs(s3_prefix)

    # Fallback: if the listing is empty, try swapping hyphens/underscores
    # in the path (common S3 naming inconsistency in the catalog CSV).
    if not tif_keys:
        alt_prefix = _swap_hyphens_underscores(s3_prefix)
        if alt_prefix != s3_prefix:
            tif_keys = _list_s3_tifs(alt_prefix)
            if tif_keys:
                s3_prefix = alt_prefix

    # If we used the fallback path, rewrite the template to match
    # the actual S3 keys so the regex and output URLs are correct.
    actual_template = template
    if s3_prefix != _template_to_s3_prefix(template):
        actual_template = template.replace("rmbl-dronedata", "rmbl_dronedata")

    slices = _parse_dates_from_keys(tif_keys, actual_template, s3_prefix)

    # Cache for next run
    cache_data = [
        {"start": s.isoformat(), "end": e.isoformat(), "url": u}
        for s, e, u in slices
    ]
    cache_path.write_text(json.dumps(cache_data, indent=2))

    return slices


def _template_to_s3_prefix(template_url: str) -> str | None:
    """Derive the S3 prefix to list from a URL template.

    Strips everything from the first template placeholder onward,
    giving us the directory prefix to enumerate.

    Example:
        https://rmbl-sdp.s3.us-east-2.amazonaws.com/imagery/rmbl_dronedata/
            GT_multispectral_weekly_05cm_v1/{year}/Altum_refl_..._{calendarday}.tif
        -> s3://rmbl-sdp/imagery/rmbl_dronedata/GT_multispectral_weekly_05cm_v1/
    """
    parsed = urlparse(template_url)
    path = parsed.path.lstrip("/")
    # Find the bucket name from the hostname (e.g., rmbl-sdp.s3.us-east-2.amazonaws.com)
    bucket = parsed.hostname.split(".")[0] if parsed.hostname else ""

    # Strip from the first { onward to get the prefix
    brace_idx = path.find("{")
    if brace_idx < 0:
        return None
    prefix = path[:brace_idx]
    return f"s3://{bucket}/{prefix}"


def _list_s3_tifs(s3_prefix: str) -> list[str]:
    """List all .tif files under an S3 prefix using the AWS CLI."""
    result = subprocess.run(
        ["aws", "s3", "ls", s3_prefix, "--recursive"],
        capture_output=True,
        text=True,
        timeout=120,
    )
    # Exit code 1 with specific error text means a real failure.
    # Exit code 0 with empty output just means no files found.
    if result.returncode != 0 and result.stderr.strip():
        raise RuntimeError(f"aws s3 ls failed: {result.stderr}")

    keys = []
    for line in result.stdout.strip().splitlines():
        # Format: "2026-04-27 18:32:29 4038309625 imagery/rmbl_dronedata/.../file.tif"
        parts = line.split(None, 3)
        if len(parts) == 4 and parts[3].endswith(".tif"):
            keys.append(parts[3])
    return keys


def _swap_hyphens_underscores(s3_prefix: str) -> str:
    """Try replacing hyphens with underscores in each path segment.

    Only swaps hyphens → underscores (not the reverse), and only in
    path segments that actually contain hyphens. This handles the known
    case where the catalog CSV has 'rmbl-dronedata' but S3 has
    'rmbl_dronedata', without mangling paths like
    'GT_multispectral_weekly_05cm_v1' that correctly use underscores.
    """
    if not s3_prefix.startswith("s3://"):
        return s3_prefix
    without_scheme = s3_prefix[5:]
    bucket, _, path = without_scheme.partition("/")
    segments = path.split("/")
    swapped = [seg.replace("-", "_") if "-" in seg else seg for seg in segments]
    new_path = "/".join(swapped)
    if new_path == path:
        return s3_prefix
    return f"s3://{bucket}/{new_path}"


def _parse_dates_from_keys(
    keys: list[str],
    template_url: str,
    s3_prefix: str,
) -> list[tuple[date, date, str]]:
    """Parse dates from S3 keys using the template's placeholder positions.

    Extracts {year}, {month}, {calendarday} from each filename by
    matching against the template pattern.
    """
    parsed = urlparse(template_url)
    bucket = parsed.hostname.split(".")[0] if parsed.hostname else ""
    base_https = f"https://{parsed.hostname}"

    # Build a regex from the template to extract date parts.
    # Only the FIRST occurrence of each placeholder gets a named group;
    # subsequent occurrences use a non-capturing \d pattern (templates
    # like .../{year}/file_{year}_{month}_{calendarday}.tif have
    # {year} twice).
    template_path = parsed.path.lstrip("/")
    template_escaped = re.escape(template_path)
    seen: set[str] = set()
    for placeholder, named, anon in [
        ("{year}",        r"(?P<year>\d{4})",        r"\d{4}"),
        ("{month}",       r"(?P<month>\d{1,2})",     r"\d{1,2}"),
        ("{calendarday}", r"(?P<calendarday>\d{1,2})", r"\d{1,2}"),
        ("{day}",         r"(?P<day>\d{1,3})",       r"\d{1,3}"),
    ]:
        escaped = re.escape(placeholder)
        while escaped in template_escaped:
            if placeholder not in seen:
                template_escaped = template_escaped.replace(escaped, named, 1)
                seen.add(placeholder)
            else:
                template_escaped = template_escaped.replace(escaped, anon, 1)
    pattern = re.compile(template_escaped)

    slices = []
    for key in sorted(keys):
        m = pattern.search(key)
        if not m:
            continue

        groups = m.groupdict()
        year = int(groups["year"])
        month = int(groups.get("month", 1))
        day = int(groups.get("calendarday", groups.get("day", 1)))

        try:
            d = date(year, month, day)
        except ValueError:
            continue

        url = f"{base_https}/{key}"
        slices.append((d, d, url))

    return sorted(slices, key=lambda x: x[0])
