# rSDP STAC Catalog Generator

Generates a static [STAC](https://stacspec.org) (SpatioTemporal Asset Catalog) from the RMBL Spatial Data Platform product catalog. The output is a tree of JSON files designed for hosting on S3 under `/stac/v1/`.

## Setup

```bash
cd stac-gen
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

Or use `make setup` to do the above in one step.

## Usage

### Generate the catalog

```bash
make build
# or directly:
python build_stac.py --output-dir out/stac/v1
```

First run fetches metadata XML and COG headers from S3 (~2 minutes for 121 products). Subsequent runs use cached data from `.cache/` and complete in seconds.

### Validate

```bash
make validate
```

Runs `stac-validator` against every generated JSON file. Errors fail the build.

### Deploy to S3

```bash
# Stage first (safe):
make sync-staging

# Smoke-test at:
# https://radiantearth.github.io/stac-browser/#/external/rmbl-sdp.s3.us-east-2.amazonaws.com/stac/v1-staging/catalog.json

# Promote to live:
make sync-live
```

### Configure CORS (one-time)

Required for browser-based STAC Browser to work:

```bash
make cors
```

## Output structure

```
out/stac/v1/
├── catalog.json                     (root)
├── ug/catalog.json                  (Upper Gunnison)
│   └── {product-slug}/
│       ├── collection.json
│       └── items/*.json
├── uer/catalog.json                 (Upper East River)
└── gt/catalog.json                  (Gothic)
```

## Options

```
python build_stac.py --help
  --output-dir DIR    Output directory (default: out/stac/v1)
  --max-workers N     Parallel fetch workers (default: 20)
  --no-cache          Disable caching of remote fetches
```

## Clearing cache

```bash
rm -rf .cache/     # re-fetches everything on next build
make clean         # removes out/ only
```
