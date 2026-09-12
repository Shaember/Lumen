# Optional all-in-one image (prefer docker-compose.yml multi-service build).
# Build from repo root: docker build -f zimaos/Dockerfile -t lumen .

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
RUN apk add --no-cache ca-certificates vips-tools caddy nodejs
COPY --from=backend-builder /lumen-server /usr/local/bin/lumen-server
COPY backend/migrations/ /app/migrations/
COPY --from=web-builder /app/build /app/web/build
COPY --from=web-builder /app/package.json /app/web/package.json
COPY --from=web-builder /app/node_modules /app/web/node_modules
COPY zimaos/Caddyfile.allinone /etc/caddy/Caddyfile
COPY zimaos/start.sh /app/start.sh
RUN chmod +x /app/start.sh
EXPOSE 80
ENV LUMEN_PORT=8080
ENV PORT=3000
ENV HOST=0.0.0.0
CMD ["/app/start.sh"]
