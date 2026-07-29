# Build the Mintlify site to a static bundle (`mint export`) and serve it with
# nginx. Mintlify has no static-build for arbitrary hosting other than export
# (a self-contained Next.js static site), so we export at build time and serve
# the result — proper static hosting, not the `mint dev` server.
FROM node:22-bookworm-slim AS builder
RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# The Mintlify project (docs.json + .mdx) lives in the repo's docs/ subdir.
COPY docs/ ./docs/
WORKDIR /build/docs
# The API reference is generated from the backend's handlers, so it is fetched
# rather than vendored — a committed copy goes stale the first time anyone edits
# a handler. docs.json points the "HTTP Gateway" group at api/openapi.yaml.
# -f so a 404 fails the build instead of writing an HTML error page into the spec.
# The grep is a sanity check on the payload, not just the status code. It scans the
# whole file rather than the first line: specgen emits root keys alphabetically, so
# the document opens with `components:` and `openapi:` sits ~4k lines down.
ARG OPENAPI_URL=https://raw.githubusercontent.com/shopnexus/server/main/api/openapi.gen.yaml
RUN curl -fsSL "$OPENAPI_URL" -o api/openapi.yaml \
 && grep -q '^openapi: ' api/openapi.yaml \
 && echo "openapi spec fetched: $(wc -c < api/openapi.yaml) bytes"
# export needs network (fetches the Mintlify runtime); fine in CI.
RUN npx -y mint@latest export --output /tmp/export.zip \
 && mkdir -p /out && unzip -q /tmp/export.zip -d /out

FROM nginx:alpine
COPY --from=builder /out /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
