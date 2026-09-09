# Build from the repository root. Only allowlisted application files enter the build.
FROM node:24-bookworm-slim AS build
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/package.json
RUN npm ci --ignore-scripts
COPY apps/backend/tsconfig*.json apps/backend/
COPY apps/backend/src apps/backend/src
COPY apps/backend/scripts apps/backend/scripts
RUN npm run backend:build

FROM node:24-bookworm-slim AS runtime
ARG RELEASE_VERSION=development
LABEL org.opencontainers.image.title="ZX Labs Games Backend" \
      org.opencontainers.image.description="Shared accounts, Google Play commerce and cloud saves" \
      org.opencontainers.image.version=$RELEASE_VERSION
ENV NODE_ENV=production
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/package.json
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY --from=build /workspace/apps/backend/dist apps/backend/dist
COPY apps/backend/migrations apps/backend/dist/ops/migrations
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health/ready',{signal:AbortSignal.timeout(4000)}).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
CMD ["node", "apps/backend/dist/server.js"]
# Worker: node apps/backend/dist/worker-main.js (disable the API healthcheck).
# Operations: node apps/backend/dist/ops/scripts/{migrate,seed-ringrush,status,retry-job}.js
