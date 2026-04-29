"""Expand SDP time-series URL templates into concrete (datetime, url) pairs.

Mirrors the R package's .resolve_time_slices() logic in
R/internal_resolve.R. The template placeholders are {year}, {month},
{day} (day-of-year, DOY 1-366), and {calendarday} (day-of-month, 1-31).

For irregular time series (e.g., Weekly drone imagery), the dates
cannot be enumerated from a formula. These products are resolved by
probing S3 to discover which files actually exist, via s3_manifest.py.
"""

from datetime import date, timedelta

from .s3_manifest import build_manifest


def resolve_time_slices(
    row: dict,
    use_cache: bool = True,
) -> list[tuple[date, date | None, str]]:
    """Expand a catalog row into time slices.

    Returns a list of (start_date, end_date, resolved_url) tuples.
    For Single products, end_date is None (instant, not interval).
    For time-series, start_date and end_date bracket the slice.
    """
    ts_type = row["TimeSeriesType"]
    template = row["Data.URL"]

    if ts_type == "Single":
        return [(row["MinDate"], None, template)]

    if ts_type == "Yearly":
        return _resolve_yearly(row, template)

    if ts_type == "Monthly":
        return _resolve_monthly(row, template)

    if ts_type == "Daily":
        return _resolve_daily(row, template)

    if ts_type == "Weekly":
        return build_manifest(row, use_cache=use_cache)

    raise ValueError(f"Unsupported TimeSeriesType: {ts_type!r}")


def _resolve_yearly(
    row: dict, template: str
) -> list[tuple[date, date, str]]:
    min_year = row["MinYear"]
    max_year = row["MaxYear"]
    slices = []
    for y in range(min_year, max_year + 1):
        url = template.replace("{year}", str(y))
        start = date(y, 1, 1)
        end = date(y, 12, 31)
        slices.append((start, end, url))
    return slices


def _resolve_monthly(
    row: dict, template: str
) -> list[tuple[date, date, str]]:
    min_date = row["MinDate"]
    max_date = row["MaxDate"]
    slices = []
    # Step month-by-month from min_date
    current = _first_of_month(min_date)
    end_bound = _first_of_month(max_date)
    while current <= end_bound:
        year_str = str(current.year)
        month_str = f"{current.month:02d}"
        url = template.replace("{year}", year_str).replace(
            "{month}", month_str
        )
        # Month interval: first of this month to last day of this month
        start = current
        if current.month == 12:
            end = date(current.year, 12, 31)
        else:
            end = date(current.year, current.month + 1, 1) - timedelta(
                days=1
            )
        slices.append((start, end, url))
        # Advance to next month
        if current.month == 12:
            current = date(current.year + 1, 1, 1)
        else:
            current = date(current.year, current.month + 1, 1)
    return slices


def _resolve_daily(
    row: dict, template: str
) -> list[tuple[date, date, str]]:
    min_date = row["MinDate"]
    max_date = row["MaxDate"]
    slices = []
    current = min_date
    while current <= max_date:
        year_str = str(current.year)
        doy_str = current.strftime("%j")  # zero-padded day of year
        url = template.replace("{year}", year_str).replace(
            "{day}", doy_str
        )
        slices.append((current, current, url))
        current += timedelta(days=1)
    return slices


def _first_of_month(d: date) -> date:
    return date(d.year, d.month, 1)
