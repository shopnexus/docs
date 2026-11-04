# document
Documentations for shopnexus

## Docs site

The developer docs are an Astro site in `web/`. See `web/README.md` for writing pages.

```bash
cd web
bun install
bun run dev        # http://localhost:4321
```

Every push to `main` builds the site and publishes it on GitHub Pages, at https://shopnexus.github.io/docs/ (`.github/workflows/pages.yml`).

## API reference

The OpenAPI spec lives in the server repository, under `api/`. The docs site explains the conventions; the spec is the reference for every endpoint.
