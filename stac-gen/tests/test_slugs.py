from lib.slugs import check_slug_collisions, product_to_slug


def test_basic_slug():
    assert product_to_slug("Basic Landcover") == "basic-landcover"


def test_slug_with_numbers():
    assert product_to_slug("20th Percentile Canopy Height") == "20th-percentile-canopy-height"


def test_slug_strips_special_chars():
    assert product_to_slug("October 2017 NAIP NDVI") == "october-2017-naip-ndvi"


def test_no_collisions_in_sample():
    products = [
        "Basic Landcover",
        "Canopy Structure Basemap",
        "Landcover Basemap",
        "Understory Cover",
    ]
    assert check_slug_collisions(products) == {}


def test_collision_detected():
    products = ["Foo Bar", "foo-bar", "Foo  Bar"]
    collisions = check_slug_collisions(products)
    assert "foo-bar" in collisions
    assert len(collisions["foo-bar"]) == 3
