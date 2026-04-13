from lib.catalog_loader import _parse_resolution, parse_catalog


def test_parse_resolution_meters():
    assert _parse_resolution("1m") == 1.0
    assert _parse_resolution("27m") == 27.0
    assert _parse_resolution("0.333m") == 0.333


def test_parse_resolution_centimeters():
    assert _parse_resolution("5cm") == 0.05


def test_parse_resolution_bare_number():
    assert _parse_resolution("3") == 3.0


def test_parse_resolution_empty():
    assert _parse_resolution("") is None
    assert _parse_resolution(None) is None


def test_parse_catalog_basic():
    csv_text = (
        "CatalogID,Release,Type,Product,Domain,Resolution,Deprecated,"
        "MinDate,MaxDate,MinYear,MaxYear,TimeSeriesType,DataType,"
        "DataUnit,DataScaleFactor,DataOffset,Data.URL,Metadata.URL\n"
        "R1D001,Release1,Hydro,Stream Flowlines,UER,1m,FALSE,"
        "1/1/2020,12/31/2022,2020,2022,Single,int16,unitless,1,0,"
        "https://example.com/data.tif,https://example.com/meta.xml\n"
    )
    rows = parse_catalog(csv_text)
    assert len(rows) == 1
    r = rows[0]
    assert r["CatalogID"] == "R1D001"
    assert r["Resolution"] == 1.0
    assert r["Deprecated"] is False
    assert r["MinYear"] == 2020
    assert r["TimeSeriesType"] == "Single"
    assert r["Data.URL"] == "https://example.com/data.tif"
