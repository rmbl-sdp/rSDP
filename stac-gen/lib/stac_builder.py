"""Construct pystac Catalog/Collection/Item objects from resolved data.

Builds a static STAC catalog tree following the layout:
    catalog.json (root)
    ├── {domain}/catalog.json (sub-catalog)
    │   └── {slug}/collection.json
    │       └── items/{item_id}.json
"""

from datetime import date, datetime, timezone

import pystac
from pystac.extensions.projection import ProjectionExtension
from pystac.extensions.raster import RasterBand, RasterExtension

from .slugs import product_to_slug

# STAC spec version — pinned for reproducibility.
STAC_VERSION = "1.0.0"

# Extension schema URLs (pinned versions).
PROJ_EXT_URL = (
    "https://stac-extensions.github.io/projection/v1.1.0/schema.json"
)
RASTER_EXT_URL = (
    "https://stac-extensions.github.io/raster/v1.1.0/schema.json"
)

COG_MEDIA_TYPE = "image/tiff; application=geotiff; profile=cloud-optimized"

# Domain display names.
DOMAIN_TITLES = {
    "UG": "Upper Gunnison",
    "UER": "Upper East River",
    "GT": "Gothic",
}


def build_root_catalog(catalog_version: str) -> pystac.Catalog:
    """Create the root STAC catalog."""
    return pystac.Catalog(
        id="rmbl-sdp",
        title="RMBL Spatial Data Platform",
        description=(
            "Curated, high-resolution geospatial datasets for domains "
            "in Western Colorado (USA) near Rocky Mountain Biological "
            "Laboratory (RMBL). Data products are cloud-optimized "
            "GeoTIFFs hosted on Amazon S3."
        ),
        extra_fields={"rmbl:catalog_version": catalog_version},
    )


def build_domain_catalog(domain: str) -> pystac.Catalog:
    """Create a sub-catalog for a spatial domain."""
    title = DOMAIN_TITLES.get(domain, domain)
    return pystac.Catalog(
        id=f"rmbl-sdp-{domain.lower()}",
        title=title,
        description=f"SDP data products for the {title} domain.",
    )


def build_collection(
    row: dict,
    metadata: dict,
    cog_info: dict,
    time_slices: list,
) -> pystac.Collection:
    """Create a Collection for a single product (catalog row).

    Parameters
    ----------
    row : dict
        Parsed catalog row from catalog_loader.
    metadata : dict
        Parsed XML metadata from metadata_parser.
    cog_info : dict
        COG header info from cog_probe.
    time_slices : list of (start_date, end_date, url)
        Resolved time slices from time_resolver.
    """
    domain = row["Domain"].lower()
    slug = product_to_slug(row["Product"])
    collection_id = f"{domain}-{slug}"

    # Temporal extent from catalog dates.
    temporal_start = row["MinDate"]
    temporal_end = row["MaxDate"]

    # Spatial extent from COG WGS84 bbox.
    bbox = cog_info.get("wgs84_bbox") or [-180, -90, 180, 90]

    extent = pystac.Extent(
        spatial=pystac.SpatialExtent(bboxes=[bbox]),
        temporal=pystac.TemporalExtent(
            intervals=[
                [
                    _to_datetime(temporal_start),
                    _to_datetime(temporal_end),
                ]
            ]
        ),
    )

    license_spdx = metadata.get("license_spdx", "proprietary")

    collection = pystac.Collection(
        id=collection_id,
        title=metadata.get("title") or row["Product"],
        description=metadata.get("description") or f"SDP product: {row['Product']}",
        license=license_spdx,
        extent=extent,
        extra_fields={
            "rmbl:domain": row["Domain"],
            "rmbl:type": row["Type"],
            "rmbl:release": row["Release"],
            "rmbl:catalog_id": row["CatalogID"],
        },
    )

    # Summaries.
    collection.summaries = pystac.Summaries(
        {
            "gsd": [row["Resolution"]] if row["Resolution"] else [],
            "proj:code": [f"EPSG:{cog_info['crs_epsg']}"]
            if cog_info.get("crs_epsg")
            else [],
        }
    )

    # Thumbnail asset (shared across all items in the collection).
    thumb_url = _derive_thumbnail_url(row)
    if thumb_url:
        collection.add_asset(
            "thumbnail",
            pystac.Asset(
                href=thumb_url,
                media_type=pystac.MediaType.PNG,
                roles=["thumbnail"],
                title=f"Thumbnail for {metadata.get('title') or row['Product']}",
            ),
        )

    return collection


def build_item(
    row: dict,
    start_date: date,
    end_date: date | None,
    resolved_url: str,
    cog_info: dict,
    metadata: dict,
) -> pystac.Item:
    """Create a STAC Item for a single time slice.

    Parameters
    ----------
    row : dict
        Parsed catalog row.
    start_date, end_date : date
        Time slice bounds. end_date is None for Single products.
    resolved_url : str
        Fully-substituted COG URL for this slice.
    cog_info : dict
        COG header info from cog_probe.
    metadata : dict
        Parsed XML metadata.
    """
    item_id = _make_item_id(row, start_date, end_date)
    bbox = cog_info.get("wgs84_bbox") or [-180, -90, 180, 90]
    geometry = _bbox_to_geometry(bbox)

    # Datetime handling. For intervals (Yearly/Monthly), we set datetime
    # to the start of the interval AND provide start/end. This is valid
    # per STAC 1.x (datetime MAY be non-null when start/end are given)
    # and avoids display issues in STAC Browser and other clients that
    # render datetime=null as "No date".
    dt = _to_datetime(start_date)
    if end_date is not None and start_date != end_date:
        start_dt = _to_datetime(start_date)
        end_dt = _to_datetime(end_date)
    else:
        start_dt = None
        end_dt = None

    properties = {"created": datetime.now(timezone.utc).isoformat()}
    if row.get("Resolution"):
        properties["gsd"] = row["Resolution"]
    if row.get("Deprecated"):
        properties["deprecated"] = True

    item = pystac.Item(
        id=item_id,
        geometry=geometry,
        bbox=bbox,
        datetime=dt,
        start_datetime=start_dt,
        end_datetime=end_dt,
        properties=properties,
        stac_extensions=[PROJ_EXT_URL, RASTER_EXT_URL],
    )

    # Projection extension fields.
    proj_ext = ProjectionExtension.ext(item, add_if_missing=True)
    if cog_info.get("crs_epsg"):
        proj_ext.apply(
            epsg=cog_info["crs_epsg"],
            bbox=cog_info.get("wgs84_bbox"),
            shape=cog_info.get("shape"),
            transform=cog_info.get("transform"),
        )

    # Data asset.
    asset = pystac.Asset(
        href=resolved_url,
        media_type=COG_MEDIA_TYPE,
        roles=["data", "cloud-optimized"],
        title=metadata.get("title") or row["Product"],
    )

    # Add asset to the item first (pystac requires an owner for extensions).
    item.add_asset("data", asset)

    # Raster extension on the asset — one entry per COG band.
    scale = row.get("DataScaleFactor")
    offset = row.get("DataOffset")
    cog_bands = cog_info.get("bands", [])
    band_count = cog_info.get("band_count", 1)

    # Detect RGB/RGBA imagery: uint8 with 3-4 bands. These don't carry
    # meaningful scale/offset/unit (they're display imagery, not
    # scientific data). All other products inherit scale/offset/unit
    # from the catalog metadata, applied uniformly across bands.
    is_rgb_imagery = (
        band_count in (3, 4)
        and cog_bands
        and all(cb.get("dtype") == "uint8" for cb in cog_bands)
    )

    if cog_bands:
        raster_bands = []
        for cb in cog_bands:
            band_kwargs = {
                "data_type": cb.get("dtype", "float32"),
                "nodata": cb.get("nodata"),
            }
            if not is_rgb_imagery:
                band_kwargs["scale"] = 1.0 / scale if scale else None
                band_kwargs["offset"] = offset
                band_kwargs["unit"] = row.get("DataUnit") or None
            raster_bands.append(RasterBand.create(**band_kwargs))
        raster_ext = RasterExtension.ext(item.assets["data"], add_if_missing=True)
        raster_ext.apply(bands=raster_bands)
    else:
        band = RasterBand.create(
            data_type="float32",
            nodata=None,
            scale=1.0 / scale if scale else None,
            offset=offset,
            unit=row.get("DataUnit") or None,
        )
        raster_ext = RasterExtension.ext(item.assets["data"], add_if_missing=True)
        raster_ext.apply(bands=[band])

    return item


def _make_item_id(row: dict, start_date: date, end_date: date | None) -> str:
    """Generate a STAC Item ID from catalog ID and time slice."""
    cat_id = row["CatalogID"]
    ts_type = row["TimeSeriesType"]

    if ts_type == "Single":
        return cat_id
    if ts_type == "Yearly":
        return f"{cat_id}_{start_date.year}"
    if ts_type == "Monthly":
        return f"{cat_id}_{start_date.year}{start_date.month:02d}"
    if ts_type == "Daily":
        return (
            f"{cat_id}_{start_date.year}"
            f"{start_date.month:02d}"
            f"{start_date.day:02d}"
        )
    return f"{cat_id}_{start_date.isoformat()}"


def _bbox_to_geometry(bbox: list[float]) -> dict:
    """Convert a [west, south, east, north] bbox to GeoJSON Polygon."""
    w, s, e, n = bbox
    return {
        "type": "Polygon",
        "coordinates": [
            [[w, s], [e, s], [e, n], [w, n], [w, s]]
        ],
    }


def _to_datetime(d: date | None) -> datetime | None:
    """Convert a date to a timezone-aware datetime at midnight UTC."""
    if d is None:
        return None
    return datetime(d.year, d.month, d.day, tzinfo=timezone.utc)


def _derive_thumbnail_url(row: dict) -> str | None:
    """Derive the thumbnail PNG URL from a catalog row's Data.URL.

    Convention: thumbnails are named {product_stem}_thumbnail.png and
    live in the same S3 directory as the data files.

    For Single products: replace .tif with _thumbnail.png.
    For time-series: the Data.URL contains template placeholders in
    the path. The thumbnail is named after the deepest NON-template
    path segment, in its parent directory. This handles both simple
    nesting (.../product_dir/file_{year}.tif) and deeper nesting
    (.../product_dir/{year}/file_{year}_{month}_{day}.tif).
    """
    url = row.get("Data.URL", "")
    if not url:
        return None

    if row["TimeSeriesType"] == "Single":
        return url.replace(".tif", "_thumbnail.png")

    # Find the deepest path segment that does NOT contain a template
    # placeholder. That's the product directory name.
    parts = url.split("/")
    product_idx = None
    for i in range(len(parts) - 1, -1, -1):
        if "{" not in parts[i] and not parts[i].endswith(".tif"):
            product_idx = i
            break

    if product_idx is None:
        return None

    stem = parts[product_idx]
    parent = "/".join(parts[:product_idx])
    thumb_url = f"{parent}/{stem}_thumbnail.png"

    # Fix known hyphen/underscore mismatch in catalog URLs.
    if "rmbl-dronedata" in thumb_url:
        thumb_url = thumb_url.replace("rmbl-dronedata", "rmbl_dronedata")

    return thumb_url
