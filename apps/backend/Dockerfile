# Build from the repository root: docker build -f apps/backend/Dockerfile .
FROM node:24-bookworm-slim AS build
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/package.json
RUN npm ci --ignore-scripts
COPY apps/backend apps/backend
RUN npm run backend:build

FROM node:24-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/backend/package.json apps/backend/package.json
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY --from=build /workspace/apps/backend/dist apps/backend/dist
USER node
EXPOSE 3000
CMD ["node", "apps/backend/dist/server.js"]
# Worker uses the same image with: node apps/backend/dist/worker-main.js
