# =============================================================================
# Hermes Suite — All-in-One Container Image
# Combines: hermes-agent + hermes-webui + hermes-dashboard
#
# Solves Podman v3.4.4 UID/GID sharing limitation between multiple containers
# by running all three services in a single container under one user.
#
# Services:
#   hermes-gateway   — Agent gateway on port 8642 (CLI, Telegram, cron, tools)
#   hermes-dashboard — Built-in monitoring dashboard on port 9119
#   hermes-webui     — Browser chat interface on port 8787
#
# Build:  scripts/local/build
# Run:    podman-compose up -d
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Use the official hermes-agent image as the base
# This already contains: Python 3.13, Node.js, npm, Playwright, agent code,
# the built-in web dashboard (hermes dashboard), the gateway, uv, and s6-overlay.
# ---------------------------------------------------------------------------
ARG AGENT_VERSION=v2026.5.29.2
FROM docker.io/nousresearch/hermes-agent:${AGENT_VERSION}

USER root
RUN touch /.dockerenv

# ---------------------------------------------------------------------------
# Stage 2: Install system dependencies needed by all services
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo \
        git \
        curl \
        nano \
        net-tools \
        iputils-ping \
        iproute2 \
        openssh-client \
        procps \
    && rm -rf /var/lib/apt/lists/*


# ---------------------------------------------------------------------------
# Stage 3: Install Browser tool dependencies for agent
# npm install + Playwright chromium (needed by browser toolset)
# ---------------------------------------------------------------------------
RUN cd /opt/hermes && \
    npm install --prefer-offline --no-audit && \
    npx playwright install --with-deps chromium && \
    rm -rf /opt/hermes/scripts/whatsapp-bridge && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Stage 4: Install supervisord via uv (not available in Debian Trixie apt)
# We install it into a dedicated venv at /opt/supervisor.
# ---------------------------------------------------------------------------
RUN uv venv /opt/supervisor && \
    uv pip install --python /opt/supervisor/bin/python3 supervisor && \
    ln -sf /opt/supervisor/bin/supervisord /usr/local/bin/supervisord && \
    ln -sf /opt/supervisor/bin/supervisorctl /usr/local/bin/supervisorctl

RUN mkdir -p /var/log/supervisor /var/run/supervisor && \
    chown -R hermes:hermes /var/log/supervisor /var/run/supervisor

# ---------------------------------------------------------------------------
# Stage 5: Install hermes-webui
# The webui is a Python web server (server.py). We clone it from GitHub
# and set up its own venv using uv (avoids python3-venv package requirement).
# The webui needs the agent's Python deps to import agent modules.
#
# PIN to a specific tag for reproducible builds — never use 'master'.
# ---------------------------------------------------------------------------
ARG HERMES_WEBUI_VERSION=v0.51.230
RUN cd /opt && \
    git clone --depth 1 --branch ${HERMES_WEBUI_VERSION} \
        https://github.com/nesquena/hermes-webui.git hermes-webui && \
    uv venv /opt/hermes-webui/venv && \
    uv pip install --python /opt/hermes-webui/venv/bin/python3 --no-cache-dir -r /opt/hermes-webui/requirements.txt && \
    uv pip install --python /opt/hermes-webui/venv/bin/python3 --no-cache-dir -e "/opt/hermes" && \
    rm -rf /opt/hermes-webui/.git

# Bake version tag into the webui
RUN echo "__version__ = '${HERMES_WEBUI_VERSION}'" > /opt/hermes-webui/api/_version.py

# Fix: webui process runs as hermes, but venv was built as root.
# Without this, lazy-dep auto-install cannot write to site-packages (#6).
RUN chown -R hermes:hermes /opt/hermes-webui/venv

# ---------------------------------------------------------------------------
# Stage 5b: Custom additions (skills, tools, extra packages)
# Copy files from custom/ into the image.  Rebuild to pick up changes.
# ---------------------------------------------------------------------------
# Ensure directories exist even if custom/ folders are empty
RUN mkdir -p /opt/hermes/skills/custom /opt/hermes-suite/bin /opt/hermes-suite/entrypoint.d /opt/hermes-suite/supervisord.d


# Official Obsidian Sync CLI (`ob`). Requires Node 22+, provided by the
# hermes-agent base image.
ARG OBSIDIAN_HEADLESS_VERSION=0.0.10
RUN npm install -g --no-audit "obsidian-headless@${OBSIDIAN_HEADLESS_VERSION}"

COPY custom/requirements.txt /tmp/custom-requirements.txt
RUN if [ -s /tmp/custom-requirements.txt ]; then \
        uv pip install --system -r /tmp/custom-requirements.txt; \
    fi

COPY custom/skills/ /opt/hermes/skills/custom/
COPY custom/bin/ /opt/hermes-suite/bin/
COPY custom/entrypoint.d/ /opt/hermes-suite/entrypoint.d/
COPY custom/supervisord.d/ /opt/hermes-suite/supervisord.d/
RUN chmod -R +x /opt/hermes-suite/bin /opt/hermes-suite/entrypoint.d 2>/dev/null || true

# Stage 6: Set up supervisord config and startup script
# ---------------------------------------------------------------------------
COPY config/supervisord.conf /etc/supervisor/supervisord.conf
RUN printf '\\n; Optional: custom services from custom/supervisord.d/*.conf\\n[include]\\nfiles = /opt/hermes-suite/supervisord.d/*.conf\\n' >> /etc/supervisor/supervisord.conf
COPY scripts/container/start.sh /opt/hermes-suite/start.sh
RUN chmod +x /opt/hermes-suite/start.sh

# ---------------------------------------------------------------------------
# Stage 7: Environment, labels, and runtime config
# ---------------------------------------------------------------------------
# Re-declare ARGs after FROM so they are available in LABEL
ARG AGENT_VERSION=v2026.5.29.2
ARG HERMES_WEBUI_VERSION=v0.51.230
ARG OBSIDIAN_HEADLESS_VERSION=0.0.10


LABEL org.opencontainers.image.title="Hermes Suite" \
      org.opencontainers.image.description="All-in-one: hermes-agent + hermes-webui + hermes-dashboard" \
      org.opencontainers.image.source="https://github.com/gwelican/hermes-suite" \
      org.opencontainers.image.vendor="gwelican" \
      hermes-suite.agent-version="${AGENT_VERSION}" \
      hermes-suite.webui-version="${HERMES_WEBUI_VERSION}" \
      hermes-suite.obsidian-headless-version="${OBSIDIAN_HEADLESS_VERSION}"

ENV PATH="/opt/hermes/.venv/bin:/opt/hermes-webui/venv/bin:$PATH"
ENV HERMES_HOME=/opt/data
ENV HERMES_DATA_DIR=/opt/data
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/.playwright

# hermes-agent web dist (built into the base image)
ENV HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist

# hermes-webui settings
ENV HERMES_WEBUI_HOST=0.0.0.0
ENV HERMES_WEBUI_PORT=8787
ENV HERMES_WEBUI_STATE_DIR=/opt/data/webui
ENV HERMES_WEBUI_DEFAULT_WORKSPACE=/workspace
ENV HERMES_WEBUI_AGENT_DIR=/opt/hermes

# Expose all service ports
EXPOSE 8642 8787 9119

# Workspace directory
RUN mkdir -p /workspace

WORKDIR /opt/hermes

# Entrypoint: run start.sh which sets up config then launches supervisord
ENTRYPOINT ["/opt/hermes-suite/start.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]
