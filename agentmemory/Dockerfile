# syntax=docker/dockerfile:1
# =============================================================================
# Standalone AgentMemory server image
# =============================================================================

FROM node:22-bookworm-slim

ARG AGENTMEMORY_VERSION=0.9.26
ARG AGENTMEMORY_III_VERSION=0.11.2
ARG TARGETARCH=amd64

LABEL org.opencontainers.image.title="AgentMemory" \
      org.opencontainers.image.description="Standalone @agentmemory/agentmemory server for Hermes" \
      org.opencontainers.image.source="https://github.com/sunnysktsang/hermes-suite" \
      org.opencontainers.image.vendor="sunnysktsang" \
      hermes-suite.agentmemory-version="${AGENTMEMORY_VERSION}" \
      hermes-suite.agentmemory-iii-version="${AGENTMEMORY_III_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --no-audit \
        "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" \
        "@agentmemory/mcp@${AGENTMEMORY_VERSION}"

# Preinstall the pinned private iii runtime so first boot does not need to
# download binaries from GitHub. Keep this in sync with agentmemory/versions.env.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) asset="iii-x86_64-unknown-linux-gnu.tar.gz" ;; \
      arm64) asset="iii-aarch64-unknown-linux-gnu.tar.gz" ;; \
      arm) asset="iii-armv7-unknown-linux-gnueabihf.tar.gz" ;; \
      *) echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/iii-hq/iii/releases/download/iii/v${AGENTMEMORY_III_VERSION}/${asset}"; \
    mkdir -p /tmp/iii /home/node/.agentmemory/bin; \
    curl -fsSL "$url" -o /tmp/iii.tgz; \
    tar -xzf /tmp/iii.tgz -C /tmp/iii; \
    iii_bin="$(find /tmp/iii -type f -name iii -perm /111 | head -n 1)"; \
    test -n "$iii_bin"; \
    install -m 0755 "$iii_bin" /home/node/.agentmemory/bin/iii; \
    /home/node/.agentmemory/bin/iii --version; \
    rm -rf /tmp/iii /tmp/iii.tgz; \
    chown -R node:node /home/node/.agentmemory

ENV NODE_ENV=production \
    HOME=/home/node \
    AGENTMEMORY_TOOLS=all \
    AGENTMEMORY_III_VERSION=0.11.2 \
    III_REST_PORT=3111

USER node
WORKDIR /home/node
VOLUME ["/home/node/.agentmemory"]

# 3111 REST/MCP proxy target, 3112 streams, 3113 viewer (loopback by default),
# 9464 metrics when enabled by iii/agentmemory config.
EXPOSE 3111 3112 3113 9464

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3111/agentmemory/livez').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["agentmemory", "--tools", "all"]
