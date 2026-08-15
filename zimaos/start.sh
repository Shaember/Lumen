#!/bin/sh
set -e

# Create data directories
mkdir -p /data/photos /data/thumbs

# Start backend in background
lumen-server &

# Wait for backend to be ready
sleep 2

# Start Caddy
caddy run --config /etc/caddy/Caddyfile
