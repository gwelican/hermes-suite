# Local Setup

## Build and run Hermes Suite

```bash
scripts/local/build
scripts/local/up
scripts/local/logs
scripts/local/down
```

Runtime selection is controlled by `config/versions.env`:

```sh
CONTAINER_RUNTIME=auto
USE_SUDO=false
```

Override at build time:

```bash
scripts/local/build --docker
scripts/local/build --podman
scripts/local/build --agent v2026.5.29.2 --webui v0.51.269
```

## Version source

All pinned versions live in one file:

```text
config/versions.env
```

This file drives:

- Docker build args
- GitHub Actions releases
- local helper scripts
- Renovate dependency updates

## GitHub Actions release flow

1. Renovate updates `config/versions.env`.
2. Merge to `main` triggers `.github/workflows/build.yml`.
3. GitHub Actions creates a release tag: `vYYYY.MM.DD.<run_number>`.
4. The tag event builds and pushes `ghcr.io/gwelican/hermes-suite`.
5. The main push also builds and pushes `ghcr.io/gwelican/hermes-suite-agentmemory`.

Hermes image tags:

```text
ghcr.io/gwelican/hermes-suite:YYYY.MM.DD.<run_number>
ghcr.io/gwelican/hermes-suite:agent-<agent>-webui-<webui>-ob-<obsidian>-am-<agentmemory>
ghcr.io/gwelican/hermes-suite:latest
```

AgentMemory image tags:

```text
ghcr.io/gwelican/hermes-suite-agentmemory:YYYY.MM.DD.<run_number>
ghcr.io/gwelican/hermes-suite-agentmemory:<agentmemory_version>
ghcr.io/gwelican/hermes-suite-agentmemory:latest
```

## Required GitHub secret

Repository secret:

```text
GH_TOKEN
```

Use a classic PAT with:

```text
repo
read:packages
write:packages
```

## AgentMemory local test

```bash
set -a
. ./config/versions.env
set +a
docker compose -f deploy/agentmemory/compose.yaml up -d
curl http://localhost:3111/agentmemory/livez
```

## Obsidian Sync

Obsidian Sync is provided by `obsidian-headless` and supervised by:

```text
custom/bin/obsidian-sync.sh
custom/supervisord.d/obsidian-sync.conf
```

Set runtime env vars as needed:

```text
OBSIDIAN_SYNC_ENABLED=true
OBSIDIAN_VAULT_PATH=/workspace/obsidian
OBSIDIAN_REMOTE_VAULT=<vault-id-or-name>
OBSIDIAN_EMAIL=<email>
OBSIDIAN_PASSWORD=<password>
```
