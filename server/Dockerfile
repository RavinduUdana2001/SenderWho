ARG NODE_IMAGE=node:22-bookworm-slim@sha256:6c74791e557ce11fc957704f6d4fe134a7bc8d6f5ca4403205b2966bd488f6b3

FROM ${NODE_IMAGE} AS base
RUN apt-get update \
    && apt-get install --no-install-recommends --yes openssl \
    && rm -rf /var/lib/apt/lists/*

FROM base AS dependencies
WORKDIR /app
ENV NODE_ENV=development \
    npm_config_audit=false \
    npm_config_fund=false \
    npm_config_update_notifier=false
COPY package.json package-lock.json ./
# Lifecycle scripts are unnecessary here: Prisma generation is explicit below.
# Keeping audit/funding network calls out of installation makes `npm ci` depend
# only on the integrity-pinned package-lock graph.
RUN npm ci --ignore-scripts --no-audit --no-fund

FROM dependencies AS builder
COPY prisma ./prisma
RUN ./node_modules/.bin/prisma generate
COPY tsconfig.json tsconfig.build.json ./
COPY scripts ./scripts
COPY src ./src
RUN npm run build

FROM builder AS production-dependencies
ENV NODE_ENV=production
RUN npm prune --omit=dev --ignore-scripts --no-audit --no-fund

# One-shot image used by Docker deployments to run migrations before the API.
FROM base AS migration
ENV NODE_ENV=production \
    CHECKPOINT_DISABLE=1
WORKDIR /app
COPY --from=dependencies --chown=node:node /app/package.json /app/package-lock.json ./
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node prisma ./prisma
RUN ./node_modules/.bin/prisma version
USER node
ENTRYPOINT ["./node_modules/.bin/prisma"]
CMD ["migrate", "deploy"]

FROM base AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=production-dependencies --chown=node:node /app/package.json ./package.json
COPY --from=production-dependencies --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/prisma ./prisma
COPY --from=builder --chown=node:node /app/dist ./dist
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/v1/health/ready',{headers:{'x-forwarded-proto':'https'}}).then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]
CMD ["node", "dist/main.js"]
