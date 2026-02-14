FROM node:20-bookworm-slim AS deps
WORKDIR /app

# Install deps first for better layer caching.
# Note: we need devDependencies for `next build` (TypeScript, eslint config, etc).
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-bookworm-slim AS builder
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Next.js app, then prune devDependencies for a lean runtime image.
RUN npm run build && npm prune --omit=dev

FROM node:20-bookworm-slim AS runner

# This runtime needs Node (Next.js) plus Python3 for `python3 -m sq_autopilot.cli`.
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=builder /app ./

# Ensure run-state directory exists and is writable.
RUN mkdir -p /app/runs

ENV PORT=3000
EXPOSE 3000

# Use shell form so $PORT expands.
CMD ["sh", "-c", "npm run start -- -p ${PORT} -H 0.0.0.0"]
