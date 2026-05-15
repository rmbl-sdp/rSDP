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

First run fetches metadata XML and COG headers from S3 (~5 minutes for 164 products). Subsequent runs use cached data from `.cache/` and complete in seconds.

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

## Refreshing issue counts without a full rebuild

Open-issue counts on STAC collections (`rmbl:open_issues_count`) are kept fresh by a separate, much lighter pipeline. Rebuilding the full STAC tree to refresh ~164 collection-level numbers would needlessly rewrite ~32K item JSONs, so this script only patches `collection.json` files in place:

```bash
# Download just the collection.json files from S3.
mkdir -p stac-tree
aws s3 sync s3://rmbl-sdp/stac/v1/ stac-tree/ \
  --exclude "*" --include "*/collection.json"

# Patch counts + report-issue/related links.
python refresh_issue_counts.py --stac-dir stac-tree

# Sync only changed collection.json files back.
aws s3 sync stac-tree/ s3://rmbl-sdp/stac/v1/ \
  --exclude "*" --include "*/collection.json" --acl public-read
```

In practice this runs automatically via a GitHub Actions workflow on
[`rmbl-sdp/sdp-products`](https://github.com/rmbl-sdp/sdp-products) on issue events plus a nightly cron fallback (see `.github/workflows/refresh-issue-counts.yml` in that repo).
