# The Astro site in web/, built at the root path (DOCS_BASE=/), served by nginx.
FROM oven/bun:1.4.4 AS build
WORKDIR /src/web
COPY web/package.json web/bun.lock ./
RUN bun install --frozen-lockfile
COPY web/ ./
ENV DOCS_BASE=/
RUN bun run build

FROM nginx:1.31.8-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/web/dist /usr/share/nginx/html
EXPOSE 80
