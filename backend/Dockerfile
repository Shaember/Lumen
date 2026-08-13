FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /lumen-server ./cmd/server

FROM alpine:3.19

RUN apk add --no-cache ca-certificates vips-tools

COPY --from=builder /lumen-server /usr/local/bin/lumen-server
COPY migrations/ /app/migrations/

EXPOSE 8080

CMD ["lumen-server"]
