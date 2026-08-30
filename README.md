# Nested Scaling of Urban Material Stocks

This repository hosts the interactive explorer for:

> Huang, K. & Lu, M. Nested economies of scale in global city mass. *Nature Cities* (accepted). Preprint: [arXiv:2507.03960](https://arxiv.org/abs/2507.03960)

**Live site:** [https://city-mass.nested-complexity.net](https://city-mass.nested-complexity.net)

Analysis code and research data are archived on Figshare (DOI to be added). This GitHub repository contains only the website.

## Explorer

- **Map:** Global → country → city. City view renders H3 resolution-7 hexagons colored by population or built mass (log scale).
- **City panel:** log(population) vs log(mass) with OLS slope and 95% CI.
- **Neighborhood panel:** neighborhood-level scatter, with an optional density overlay.

Static JSON under `web/public/webdata/` is what the site serves. It is visualization data, not the research archive.

## Local development

```bash
cd web
npm ci
export VITE_MAPTILER_KEY=your_key   # free at maptiler.com
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).

## Deployment

Push to `main` deploys `web/` to GitHub Pages via [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml). The custom domain is `city-mass.nested-complexity.net`.

Requires the `MAPTILER_KEY` repository secret.

## License

MIT — see [LICENSE](LICENSE).
