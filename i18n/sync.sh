#!/bin/sh
# Copies format-cases.json into the server, the app and the website, which
# each test against their copy; --check fails when a copy differs.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
src="$here/format-cases.json"
for dst in \
  "$root/server/internal/platform/locale/testdata/format-cases.json" \
  "$root/clients/app-android/core/model/src/test/resources/format-cases.json" \
  "$root/clients/website/src/i18n/format-cases.json"; do
  if [ "${1:-}" = "--check" ]; then
    cmp -s "$src" "$dst" || { echo "differs: $dst"; exit 1; }
  else
    mkdir -p "$(dirname "$dst")" && cp "$src" "$dst"
  fi
done
