# Hermes Suite

Hermes Suite builds an all-in-one Hermes container plus a standalone AgentMemory container.

## Repository layout

```text
config/versions.env          Single source of truth for pinned component versions
docker/hermes.Dockerfile     Main Hermes Suite image
docker/agentmemory.Dockerfile Standalone AgentMemory image
deploy/compose.yaml          Local Hermes Suite compose file
deploy/agentmemory/          AgentMemory compose/Kubernetes examples
scripts/local/               Local build/up/down/logs helpers
scripts/container/start.sh   Container entrypoint copied into the Hermes image
custom/                      Custom Hermes skills, binaries, Python deps, supervisord snippets
.github/workflows/           GitHub Actions release/build workflows
```

## Versions and releases

Pinned upstream component versions live in:

```text
config/versions.env
```

Renovate updates this file. On every merge to `main`, GitHub Actions creates a release tag:

```text
vYYYY.MM.DD.<github_run_number>
```

The Hermes image is published with:

```text
ghcr.io/gwelican/hermes-suite:YYYY.MM.DD.<github_run_number>
ghcr.io/gwelican/hermes-suite:agent-<agent>-webui-<webui>-ob-<obsidian>-am-<agentmemory>
ghcr.io/gwelican/hermes-suite:latest
```

Homelab Renovate should track the simple tag:

```text
ghcr.io/gwelican/hermes-suite:YYYY.MM.DD.<github_run_number>
```

AgentMemory is published with:

```text
ghcr.io/gwelican/hermes-suite-agentmemory:YYYY.MM.DD.<github_run_number>
ghcr.io/gwelican/hermes-suite-agentmemory:<agentmemory_version>
ghcr.io/gwelican/hermes-suite-agentmemory:latest
```

## Local build

```bash
scripts/local/build
```

Force a runtime:

```bash
scripts/local/build --docker
scripts/local/build --podman
```

Override pinned versions for a local test:

```bash
scripts/local/build --agent v2026.5.29.2 --webui v0.51.269 --obsidian 0.0.10
```

## Local run

```bash
scripts/local/up
scripts/local/logs
scripts/local/down
```

The compose file is `deploy/compose.yaml`. By default it uses:

```text
ghcr.io/gwelican/hermes-suite:${HERMES_SUITE_IMAGE_TAG}
```

`scripts/local/up` sets `HERMES_SUITE_IMAGE_TAG` from `config/versions.env`.

## AgentMemory

Standalone AgentMemory files are under:

```text
deploy/agentmemory/
docker/agentmemory.Dockerfile
```

Local compose:

```bash
set -a
. ./config/versions.env
set +a
docker compose -f deploy/agentmemory/compose.yaml up -d
curl http://localhost:3111/agentmemory/livez
```

## CI secrets

GitHub Actions needs a classic PAT stored as repository secret:

```text
GH_TOKEN
```

Required scopes:

```text
repo
read:packages
write:packages
```

## Base image mirror

`docker/agentmemory.Dockerfile` uses:

```text
ghcr.io/gwelican/node:24-bookworm-slim
```

The workflow `.github/workflows/mirror-node-base.yml` mirrors Docker Hub's Node image into GHCR to avoid Docker Hub anonymous pull limits.
