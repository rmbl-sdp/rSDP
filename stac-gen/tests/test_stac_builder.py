from datetime import date

from lib.stac_builder import _bbox_to_geometry, _make_item_id


def test_make_item_id_single():
    row = {"CatalogID": "R1D014", "TimeSeriesType": "Single"}
    assert _make_item_id(row, date(2020, 1, 1), None) == "R1D014"


def test_make_item_id_yearly():
    row = {"CatalogID": "R4D001", "TimeSeriesType": "Yearly"}
    assert _make_item_id(row, date(2003, 1, 1), date(2003, 12, 31)) == "R4D001_2003"


def test_make_item_id_monthly():
    row = {"CatalogID": "R4D008", "TimeSeriesType": "Monthly"}
    assert _make_item_id(row, date(2003, 6, 1), date(2003, 6, 30)) == "R4D008_200306"


def test_make_item_id_daily():
    row = {"CatalogID": "R4D004", "TimeSeriesType": "Daily"}
    assert _make_item_id(row, date(2003, 1, 15), date(2003, 1, 15)) == "R4D004_20030115"


def test_bbox_to_geometry():
    geom = _bbox_to_geometry([-107.0, 38.0, -106.0, 39.0])
    assert geom["type"] == "Polygon"
    coords = geom["coordinates"][0]
    assert len(coords) == 5  # closed ring
    assert coords[0] == coords[-1]  # first == last
    assert [-107.0, 38.0] in coords
    assert [-106.0, 39.0] in coords
