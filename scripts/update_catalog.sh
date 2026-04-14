#!/usr/bin/env bash
#
# update_catalog.sh — Update the rSDP R package and STAC catalog from
# the upstream product table CSV on S3.
#
# Run this after uploading a new SDP_product_table_*.csv to S3.
#
# Usage:
#   ./scripts/update_catalog.sh [--skip-stac-sync]
#
# What it does:
#   1. Regenerates R/sysdata.rda from the catalog CSV (R side)
#   2. Rebuilds the static STAC catalog from the same CSV (Python side)
#   3. Runs R tests to verify the package still works
#   4. Runs Python tests to verify the STAC tooling
#   5. Syncs the STAC catalog to S3 staging (unless --skip-stac-sync)
#
# Prerequisites:
#   - R with devtools, usethis packages installed
#   - Python venv set up in stac-gen/ (run `cd stac-gen && make setup`)
#   - AWS CLI configured (for STAC sync step)
#
# After running:
#   - Review the changes with `git diff`
#   - Commit, push, and merge
#   - Promote STAC staging to live: cd stac-gen && make sync-live

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SKIP_SYNC=false
if [[ "${1:-}" == "--skip-stac-sync" ]]; then
    SKIP_SYNC=true
fi

echo "=== Step 1: Regenerate R/sysdata.rda ==="
Rscript -e 'source("data-raw/SDP_catalog.R")'
echo ""

echo "=== Step 2: Rebuild STAC catalog ==="
cd stac-gen
# Clear the catalog CSV cache so we pick up the new URL
rm -f .cache/catalog*.csv
.venv/bin/python build_stac.py --output-dir out/stac/v1 2>&1 | grep -v "boto3 not available"
cd "$REPO_ROOT"
echo ""

echo "=== Step 3: Run R tests ==="
Rscript -e 'devtools::test()' 2>&1 | tail -5
echo ""

echo "=== Step 4: Run Python tests ==="
cd stac-gen
.venv/bin/python -m pytest tests/ -q
cd "$REPO_ROOT"
echo ""

if [[ "$SKIP_SYNC" == false ]]; then
    echo "=== Step 5: Sync STAC to S3 staging ==="
    cd stac-gen
    aws s3 sync out/stac/v1 s3://rmbl-sdp/stac/v1-staging/ --acl public-read
    cd "$REPO_ROOT"
    echo ""
    echo "Staging sync complete. Review at:"
    echo "  https://radiantearth.github.io/stac-browser/#/external/rmbl-sdp.s3.us-east-2.amazonaws.com/stac/v1-staging/catalog.json"
    echo ""
    echo "When satisfied, promote to live:"
    echo "  cd stac-gen && make sync-live"
else
    echo "=== Step 5: Skipped STAC S3 sync (--skip-stac-sync) ==="
fi

echo ""
echo "=== Summary ==="
NROWS=$(Rscript -e 'devtools::load_all(quiet=TRUE); cat(nrow(sdp_get_catalog(deprecated=c(FALSE,TRUE))))')
NJSON=$(find stac-gen/out/stac/v1 -name '*.json' | wc -l | tr -d ' ')
echo "  R catalog rows: $NROWS"
echo "  STAC JSON files: $NJSON"
echo ""
echo "Review changes with: git diff --stat"
echo "Then commit and push when ready."
