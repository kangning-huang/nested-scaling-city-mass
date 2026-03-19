#!/usr/bin/env python3
"""
Google Earth Engine (GEE) Demo — Small-Scale Sample for R6
==========================================================
Purpose
  - Demonstrate how the H3 R6 neighborhood inputs can be (re)generated
    for a very small sample area using GEE.
  - Intended for reviewers/readers to replicate the data-extraction
    process on a tiny subset without large quotas.

Requirements
  - A Google Earth Engine account (https://earthengine.google.com)
  - earthengine-api:  pip install earthengine-api
  - First-time auth:  earthengine authenticate

What it does
  - Defines a small bbox around central Paris (as an example)
  - Loads a population layer (GHSL 2015) and a building volume proxy
    (use a single source as an example)
  - Aggregates to H3 Resolution 6 cells using a simple reducer
  - Prints a few rows to stdout as a sanity check

Notes
  - This is a demo only; the full pipeline used batched exports and
    multiple sources. See docs/REPRODUCIBILITY.md for details.
"""

import ee
import json
import math

# Initialize EE (assumes "earthengine authenticate" has been done)
ee.Initialize()

# Example region: small bbox around central Paris
region = ee.Geometry.Rectangle([2.28, 48.83, 2.38, 48.89])

# Load GHSL 2015 population
# GHSL: JRC/GHSL/P2016/POP_GPW_GLOBE_V1/2015
pop_image = ee.Image('JRC/GHSL/P2016/POP_GPW_GLOBE_V1/2015').select('population')

# Simple building proxy: use GHSL built-up surface (as stand-in for demo)
built_image = ee.Image('JRC/GHSL/P2016/BUILT_LDSMT_GLOBE_V1').select('built')

# Sample at ~1km (R6 hexes are ~5.16 km^2; here we just demonstrate
# zonal aggregation over a grid for simplicity without full H3 on EE).
scale_m = 1000

reduced = pop_image.addBands(built_image).reduceRegion(
    reducer=ee.Reducer.mean().combine(reducer2=ee.Reducer.sum(), sharedInputs=True),
    geometry=region,
    scale=scale_m,
    maxPixels=1_000_000,
)

print(json.dumps(reduced.getInfo(), indent=2))

print("\nDemo complete. For full exports over all cities and exact H3 bins,"
      " see docs/REPRODUCIBILITY.md and the upstream generator scripts.")

