#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export PROJECT_DIR="$(pwd)"
export DIST="$PROJECT_DIR/dist"
export PORT="${PORT:-3000}"
/usr/bin/time -p bash -c 'echo "PROJECT_DIR=$PROJECT_DIR PORT=$PORT DIST=$DIST"'
/usr/bin/time -p test -f "$DIST/index.html"
/usr/bin/time -p bash -c 'if [ -f package.json ]; then npm ci --no-audit --no-fund; fi'
/usr/bin/time -p bash -c 'if [ -f src/index.html ] && { [ ! -f dist/index.html ] || [ src/index.html -nt dist/index.html ]; }; then mkdir -p dist; cp src/index.html dist/index.html; echo rebuilt; else echo "dist up to date"; fi'
/usr/bin/time -p bash -c 'OUT="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}/deployment-output.json"; printf "{\"project\":\"%s\",\"directory\":\"%s\"}" "$PROJECT_DIR" "$DIST" > "$OUT"; cat "$OUT"; echo'
time -p exec python3 -m http.server "$PORT" --directory "$DIST"
