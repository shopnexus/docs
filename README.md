# document
Documentations for shopnexus

## API reference

`docs/api/openapi.yaml` is **not committed** — it is generated from the backend's
handlers (`server/api/openapi.gen.yaml`, guarded by a drift-check workflow in that
repo) and fetched at build time by the Dockerfile. Refresh it locally with:

```bash
npm run spec
```

Do not commit a copy: it goes stale the first time anyone edits a handler.
