"""Read COG headers from S3 to extract proj/raster extension fields.

Key optimization: reads the header ONCE per product (not per time slice),
since resolution/shape/transform/nodata/dtype are invariant within a
product's time series. Caches results to .cache/headers/.
"""

import hashlib
import json
from pathlib import Path

import rasterio
from rasterio.warp import transform_bounds

CACHE_DIR = Path(__file__).resolve().parent.parent / ".cache" / "headers"


def probe_cog(
    cog_url: str,
    catalog_id: str,
    use_cache: bool = True,
) -> dict:
    """Read a COG header and return STAC-ready raster/proj fields.

    Returns a dict with keys:
        width, height, dtype, nodata, transform (list of 6 floats),
        crs_epsg, wgs84_bbox (list of 4 floats), shape (list of 2 ints)
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = CACHE_DIR / f"{catalog_id}.json"

    if use_cache and cache_path.exists():
        return json.loads(cache_path.read_text())

    result = _read_header(cog_url)
    cache_path.write_text(json.dumps(result, indent=2))
    return result


def _read_header(cog_url: str) -> dict:
    """Open a COG via /vsicurl/ and extract header info."""
    with rasterio.open(cog_url) as ds:
        epsg = ds.crs.to_epsg() if ds.crs else None
        native_bounds = ds.bounds

        # Compute WGS84 bbox with densified edges to avoid corner-only
        # reprojection errors (Plan agent recommendation).
        if ds.crs:
            wgs84_bbox = list(
                transform_bounds(
                    ds.crs,
                    "EPSG:4326",
                    native_bounds.left,
                    native_bounds.bottom,
                    native_bounds.right,
                    native_bounds.top,
                    densify_pts=21,
                )
            )
        else:
            wgs84_bbox = None

        # Map numpy dtype to STAC raster:bands data_type enum.
        dtype_map = {
            "uint8": "uint8",
            "uint16": "uint16",
            "int16": "int16",
            "uint32": "uint32",
            "int32": "int32",
            "float32": "float32",
            "float64": "float64",
        }
        raw_dtype = str(ds.dtypes[0])
        stac_dtype = dtype_map.get(raw_dtype, raw_dtype)

        return {
            "width": ds.width,
            "height": ds.height,
            "dtype": stac_dtype,
            "nodata": ds.nodata,
            "transform": list(ds.transform)[:6],
            "crs_epsg": epsg,
            "wgs84_bbox": wgs84_bbox,
            "shape": [ds.height, ds.width],
        }
