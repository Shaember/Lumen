FROM golang:1.22-alpine AS backend-builder
RUN apk add --no-cache git
WORKDIR /app
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /lumen-server ./cmd/server

FROM node:20-alpine AS web-builder
WORKDIR /app
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ .
RUN npm run build

FROM alpine:3.19
RUN apk add --no-cache ca-certificates vips-tools caddy

# Backend
COPY --from=backend-builder /lumen-server /usr/local/bin/lumen-server
COPY backend/migrations/ /app/migrations/

# Web
COPY --from=web-builder /app/build /app/web/build

# Caddy
COPY zimaos/Caddyfile /etc/caddy/Caddyfile

# Startup script
COPY zimaos/start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 3000

CMD ["/app/start.sh"]
