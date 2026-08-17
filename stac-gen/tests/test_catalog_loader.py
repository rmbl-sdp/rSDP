import pytest

from lib.catalog_loader import (
    _parse_resolution,
    parse_catalog,
    validate_required_fields,
    validate_unique_catalog_ids,
)


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
        "CatalogID,Release,Type,Product,Domain,Resolution,Deprecated,NewVersionID,"
        "MinDate,MaxDate,MinYear,MaxYear,TimeSeriesType,DataType,"
        "DataUnit,DataScaleFactor,DataOffset,Data.URL,Metadata.URL\n"
        "R1D001,Release1,Hydro,Stream Flowlines,UER,1m,FALSE,,"
        "1/1/2020,12/31/2022,2020,2022,Single,int16,unitless,1,0,"
        "https://example.com/data.tif,https://example.com/meta.xml\n"
    )
    rows = parse_catalog(csv_text)
    assert len(rows) == 1
    r = rows[0]
    assert r["CatalogID"] == "R1D001"
    assert r["Resolution"] == 1.0
    assert r["Deprecated"] is False
    assert r["NewVersionID"] is None
    assert r["MinYear"] == 2020
    assert r["TimeSeriesType"] == "Single"
    assert r["Data.URL"] == "https://example.com/data.tif"


def test_validate_required_fields_passes_complete_rows():
    rows = [
        {
            "CatalogID": "R1D001",
            "Data.URL": "https://example.com/data.tif",
            "Metadata.URL": "https://example.com/meta.xml",
        }
    ]
    validate_required_fields(rows)  # should not raise


def test_validate_required_fields_rejects_missing_data_url():
    rows = [
        {
            "CatalogID": "R6D007",
            "Data.URL": "",
            "Metadata.URL": "https://example.com/meta.xml",
        }
    ]
    with pytest.raises(ValueError, match="Data.URL.*R6D007"):
        validate_required_fields(rows)


def test_validate_required_fields_rejects_missing_metadata_url():
    rows = [
        {
            "CatalogID": "R6D008",
            "Data.URL": "https://example.com/data.tif",
            "Metadata.URL": "   ",  # whitespace-only counts as empty
        }
    ]
    with pytest.raises(ValueError, match="Metadata.URL.*R6D008"):
        validate_required_fields(rows)


def test_validate_required_fields_reports_all_offenders():
    rows = [
        {"CatalogID": "R6D007", "Data.URL": "", "Metadata.URL": ""},
        {"CatalogID": "R6D008", "Data.URL": "", "Metadata.URL": ""},
    ]
    with pytest.raises(ValueError) as exc:
        validate_required_fields(rows)
    msg = str(exc.value)
    assert "R6D007" in msg
    assert "R6D008" in msg
    assert "Data.URL" in msg
    assert "Metadata.URL" in msg


def test_validate_unique_catalog_ids_passes_unique_rows():
    rows = [{"CatalogID": "R6D006"}, {"CatalogID": "R6D007"}]
    validate_unique_catalog_ids(rows)  # should not raise


def test_validate_unique_catalog_ids_rejects_duplicates():
    rows = [
        {"CatalogID": "R6D006"},
        {"CatalogID": "R6D006"},
        {"CatalogID": "R6D006"},
        {"CatalogID": "R6D007"},
    ]
    with pytest.raises(ValueError, match="Duplicate CatalogIDs.*R6D006"):
        validate_unique_catalog_ids(rows)


def test_parse_catalog_deprecated_with_new_version_id():
    csv_text = (
        "CatalogID,Release,Type,Product,Domain,Resolution,Deprecated,NewVersionID,"
        "MinDate,MaxDate,MinYear,MaxYear,TimeSeriesType,DataType,"
        "DataUnit,DataScaleFactor,DataOffset,Data.URL,Metadata.URL\n"
        "R4D001,Release4,Snow,Snowpack Persistence,UG,27m,TRUE,R6D007,"
        "1/1/2018,12/31/2024,2018,2024,Yearly,float32,days,1,0,"
        "https://example.com/r4d001.tif,https://example.com/r4d001.xml\n"
    )
    rows = parse_catalog(csv_text)
    assert rows[0]["Deprecated"] is True
    assert rows[0]["NewVersionID"] == "R6D007"
