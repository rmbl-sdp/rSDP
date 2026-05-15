from datetime import date

from lib.stac_builder import (
    VERSION_EXT_URL,
    _bbox_to_geometry,
    _make_item_id,
    build_collection,
    build_item,
    link_successor_version,
)


def _row(cat_id="R4D001", deprecated=False, new_version_id=None):
    return {
        "CatalogID": cat_id,
        "Release": "Release4",
        "Type": "Snow",
        "Product": f"Product {cat_id}",
        "Domain": "UG",
        "Resolution": 27.0,
        "Deprecated": deprecated,
        "NewVersionID": new_version_id,
        "MinDate": date(2018, 1, 1),
        "MaxDate": date(2024, 12, 31),
        "MinYear": 2018,
        "MaxYear": 2024,
        "TimeSeriesType": "Yearly",
        "TimeSeriesRegularity": "Regular",
        "DataType": "float32",
        "DataUnit": "days",
        "DataScaleFactor": 1.0,
        "DataOffset": 0.0,
        "Data.URL": f"https://example.com/{cat_id}_{{year}}.tif",
        "Metadata.URL": f"https://example.com/{cat_id}.xml",
        "ColorRampDefault": "viridis",
    }


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


def test_build_collection_marks_deprecated_with_new_version():
    row = _row(cat_id="R4D001", deprecated=True, new_version_id="R6D007")
    coll = build_collection(row, metadata={}, cog_info={}, time_slices=[])
    assert coll.extra_fields["deprecated"] is True
    assert coll.extra_fields["rmbl:new_version_id"] == "R6D007"
    assert VERSION_EXT_URL in coll.stac_extensions


def test_build_collection_skips_deprecated_fields_for_current_products():
    row = _row(cat_id="R6D007", deprecated=False)
    coll = build_collection(row, metadata={}, cog_info={}, time_slices=[])
    assert "deprecated" not in coll.extra_fields
    assert "rmbl:new_version_id" not in coll.extra_fields
    assert VERSION_EXT_URL not in coll.stac_extensions


def test_build_item_marks_deprecated_and_declares_version_ext():
    row = _row(cat_id="R4D001", deprecated=True, new_version_id="R6D007")
    item = build_item(
        row,
        start_date=date(2020, 1, 1),
        end_date=date(2020, 12, 31),
        resolved_url="https://example.com/R4D001_2020.tif",
        cog_info={},
        metadata={},
    )
    assert item.properties.get("deprecated") is True
    assert VERSION_EXT_URL in item.stac_extensions


def test_build_collection_emits_report_issue_and_related_links():
    row = _row(cat_id="R4D001")
    coll = build_collection(row, metadata={}, cog_info={}, time_slices=[])
    rels = [(l.rel, l.href if l.target is None else l.target) for l in coll.links]
    rel_names = {r for r, _ in rels}
    assert "report-issue" in rel_names
    assert "related" in rel_names
    report_href = next(t for r, t in rels if r == "report-issue")
    assert "catalog_id=R4D001" in report_href
    related_href = next(t for r, t in rels if r == "related")
    assert "product:R4D001" in related_href.replace("%3A", ":")


def test_build_collection_sets_open_issues_count_when_provided():
    row = _row(cat_id="R4D008")
    coll = build_collection(row, metadata={}, cog_info={}, time_slices=[],
                            open_issues_count=3)
    assert coll.extra_fields["rmbl:open_issues_count"] == 3


def test_build_collection_omits_open_issues_count_when_unknown():
    row = _row(cat_id="R4D008")
    coll = build_collection(row, metadata={}, cog_info={}, time_slices=[])
    assert "rmbl:open_issues_count" not in coll.extra_fields


def test_link_successor_version_adds_reciprocal_rel_links():
    old_row = _row(cat_id="R4D001", deprecated=True, new_version_id="R6D007")
    new_row = _row(cat_id="R6D007", deprecated=False)
    old = build_collection(old_row, metadata={}, cog_info={}, time_slices=[])
    new = build_collection(new_row, metadata={}, cog_info={}, time_slices=[])
    link_successor_version(old, new)
    assert any(link.rel == "successor-version" and link.target is new
               for link in old.links)
    assert any(link.rel == "predecessor-version" and link.target is old
               for link in new.links)
