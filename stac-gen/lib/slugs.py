"""Product name to URL-safe slug conversion.

product-slug = lowercased Product column with non-alphanumerics replaced
by hyphens and consecutive hyphens collapsed.
"""

import re


def product_to_slug(product_name: str) -> str:
    """Convert a catalog Product name to a URL-safe slug.

    >>> product_to_slug("Basic Landcover")
    'basic-landcover'
    >>> product_to_slug("20th Percentile Canopy Height")
    '20th-percentile-canopy-height'
    >>> product_to_slug("October 2017 NAIP NDVI")
    'october-2017-naip-ndvi'
    """
    slug = product_name.lower().strip()
    slug = re.sub(r"[^a-z0-9]+", "-", slug)
    slug = slug.strip("-")
    return slug


def check_slug_collisions(products: list[str]) -> dict[str, list[str]]:
    """Check for slug collisions across a list of product names.

    Returns a dict mapping each colliding slug to the list of product
    names that produce it. Empty dict means no collisions.
    """
    slug_map: dict[str, list[str]] = {}
    for name in products:
        slug = product_to_slug(name)
        slug_map.setdefault(slug, []).append(name)
    return {s: names for s, names in slug_map.items() if len(names) > 1}
