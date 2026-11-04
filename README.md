# document
Documentations for shopnexus

## Docs site

The developer docs are an Astro site in `web/`. See `web/README.md` for writing pages.

```bash
cd web
bun install
bun run dev        # http://localhost:4321
```

`docker compose up --build` serves the built site with nginx at `http://localhost:5000`, the same image CI pushes to GHCR.

## API reference

The OpenAPI spec lives in the server repository, under `api/`. The docs site explains the conventions; the spec is the reference for every endpoint.
