from datetime import date

from lib.time_resolver import resolve_time_slices


def _fake_row(ts_type, **kwargs):
    base = {
        "CatalogID": "FAKE01",
        "TimeSeriesType": ts_type,
        "Data.URL": "https://test.example/{year}.tif",
        "MinDate": date(2003, 1, 1),
        "MaxDate": date(2005, 12, 31),
        "MinYear": 2003,
        "MaxYear": 2005,
    }
    base.update(kwargs)
    return base


def test_single_returns_one_slice():
    row = _fake_row("Single", **{"Data.URL": "https://test.example/data.tif"})
    slices = resolve_time_slices(row)
    assert len(slices) == 1
    start, end, url = slices[0]
    assert end is None
    assert url == "https://test.example/data.tif"


def test_yearly_returns_correct_count():
    row = _fake_row("Yearly")
    slices = resolve_time_slices(row)
    assert len(slices) == 3  # 2003, 2004, 2005
    years = [s[0].year for s in slices]
    assert years == [2003, 2004, 2005]


def test_yearly_url_substitution():
    row = _fake_row("Yearly")
    slices = resolve_time_slices(row)
    assert slices[0][2] == "https://test.example/2003.tif"
    assert slices[2][2] == "https://test.example/2005.tif"


def test_monthly_returns_correct_count():
    row = _fake_row(
        "Monthly",
        **{
            "Data.URL": "https://test.example/{year}_{month}.tif",
            "MinDate": date(2003, 1, 1),
            "MaxDate": date(2003, 3, 1),
        },
    )
    slices = resolve_time_slices(row)
    assert len(slices) == 3  # Jan, Feb, Mar


def test_monthly_url_substitution():
    row = _fake_row(
        "Monthly",
        **{
            "Data.URL": "https://test.example/{year}_{month}.tif",
            "MinDate": date(2003, 6, 1),
            "MaxDate": date(2003, 8, 1),
        },
    )
    slices = resolve_time_slices(row)
    assert slices[0][2] == "https://test.example/2003_06.tif"
    assert slices[2][2] == "https://test.example/2003_08.tif"


def test_daily_returns_correct_count():
    row = _fake_row(
        "Daily",
        **{
            "Data.URL": "https://test.example/{year}_{day}.tif",
            "MinDate": date(2003, 1, 1),
            "MaxDate": date(2003, 1, 5),
        },
    )
    slices = resolve_time_slices(row)
    assert len(slices) == 5


def test_daily_url_substitution():
    row = _fake_row(
        "Daily",
        **{
            "Data.URL": "https://test.example/{year}_{day}.tif",
            "MinDate": date(2003, 1, 1),
            "MaxDate": date(2003, 1, 3),
        },
    )
    slices = resolve_time_slices(row)
    # Jan 1 = DOY 001, Jan 2 = DOY 002, Jan 3 = DOY 003
    assert slices[0][2] == "https://test.example/2003_001.tif"
    assert slices[1][2] == "https://test.example/2003_002.tif"
    assert slices[2][2] == "https://test.example/2003_003.tif"


def test_yearly_intervals_have_start_and_end():
    row = _fake_row("Yearly")
    slices = resolve_time_slices(row)
    start, end, _ = slices[0]
    assert start == date(2003, 1, 1)
    assert end == date(2003, 12, 31)
