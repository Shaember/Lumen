FROM node:20-alpine AS builder

WORKDIR /app
COPY package.json ./
COPY package-lock.json.gz.b64* package-lock.json* ./
RUN if [ -f package-lock.json.gz.b64 ]; then \
      base64 -d package-lock.json.gz.b64 | gunzip > package-lock.json && npm ci; \
    elif [ -f package-lock.json ]; then npm ci; \
    else npm install; fi

COPY . .
RUN npm run build

FROM node:20-alpine

WORKDIR /app
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules

ENV PORT=3000
ENV HOST=0.0.0.0

CMD ["node", "build"]
