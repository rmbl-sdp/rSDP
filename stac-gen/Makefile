.PHONY: setup build validate sync-staging sync-live cors clean

PYTHON ?= python3
OUT_DIR = out/stac/v1
STAGING_PREFIX = s3://rmbl-sdp/stac/v1-staging
LIVE_PREFIX = s3://rmbl-sdp/stac/v1

setup:
	$(PYTHON) -m venv .venv
	.venv/bin/pip install -e ".[dev]"

build:
	$(PYTHON) build_stac.py --output-dir $(OUT_DIR)

validate:
	@echo "Running stac-validator on all generated JSON files..."
	@find $(OUT_DIR) -name '*.json' -exec $(PYTHON) -m stac_validator {} \;
	@echo "Validation complete."

sync-staging:
	aws s3 sync $(OUT_DIR) $(STAGING_PREFIX)

sync-live:
	aws s3 sync $(STAGING_PREFIX) $(LIVE_PREFIX)

cors:
	aws s3api put-bucket-cors --bucket rmbl-sdp --cors-configuration file://s3-cors.json

clean:
	rm -rf $(OUT_DIR)

test:
	$(PYTHON) -m pytest tests/ -v
