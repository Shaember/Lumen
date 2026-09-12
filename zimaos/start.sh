#!/bin/sh
set -e
mkdir -p /data/photos /data/thumbs
export LUMEN_DATA_DIR="${LUMEN_DATA_DIR:-/data}"
export LUMEN_DB_PATH="${LUMEN_DB_PATH:-/data/lumen.db}"
export LUMEN_PORT="${LUMEN_PORT:-8080}"
lumen-server &
cd /app/web && node build &
sleep 2
exec caddy run --config /etc/caddy/Caddyfile
