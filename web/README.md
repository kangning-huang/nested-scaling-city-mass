# Web app (Vite + React + MapLibre + deck.gl)

Live site: [https://city-mass.nested-complexity.net](https://city-mass.nested-complexity.net)

## Getting started

1. Install Node 18+ and npm.
2. Install deps: `npm ci` (inside `web/`).
3. Provide a MapTiler key via `VITE_MAPTILER_KEY` (free at [maptiler.com](https://www.maptiler.com)).
4. Run dev: `npm run dev`.

## Data

Static artifacts are served from `public/webdata/`. These files are required to render the UI:

- `webdata/countries.geojson`
- `webdata/cities_agg/`
- `webdata/scatter_samples/`
- `webdata/regression/`
- `webdata/hex/`
- `webdata/index/`

## Deploy

Push to `main`. The GitHub Actions workflow builds `web/` and publishes to the `gh-pages` branch (custom domain `city-mass.nested-complexity.net`).

Set the `MAPTILER_KEY` repository secret before deploying.
