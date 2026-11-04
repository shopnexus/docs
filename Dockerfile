# Build the Astro site in web/ to static files and serve them with nginx.
FROM oven/bun:1 AS builder
WORKDIR /build
COPY web/package.json web/bun.lock ./
RUN bun install --frozen-lockfile
COPY web/ ./
# DOCS_BASE and DOCS_INTERNAL pass through to astro.config.ts (see web/README.md).
ARG DOCS_BASE=/
ARG DOCS_INTERNAL=false
ENV DOCS_BASE=$DOCS_BASE DOCS_INTERNAL=$DOCS_INTERNAL
RUN bun run build

FROM nginx:alpine
COPY --from=builder /build/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
