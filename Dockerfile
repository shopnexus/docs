# Build the Mintlify site to a static bundle (`mint export`) and serve it with
# nginx. Mintlify has no static-build for arbitrary hosting other than export
# (a self-contained Next.js static site), so we export at build time and serve
# the result — proper static hosting, not the `mint dev` server.
FROM node:22-bookworm-slim AS builder
RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# The Mintlify project (docs.json + .mdx) lives in the repo's docs/ subdir.
COPY docs/ ./docs/
WORKDIR /build/docs
# export needs network (fetches the Mintlify runtime); fine in CI.
RUN npx -y mint@latest export --output /tmp/export.zip \
 && mkdir -p /out && unzip -q /tmp/export.zip -d /out

FROM nginx:alpine
COPY --from=builder /out /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
