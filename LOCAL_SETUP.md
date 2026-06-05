# Hermes Suite Local Setup

## Automated CI/CD (Woodpecker + Renovate)

### What it does

1. Renovate monitors `nousresearch/hermes-agent` (Docker) and `nesquena/hermes-webui` (GitHub tags) for new releases.
2. When an update is available, Renovate opens a PR that edits `versions.env`.
3. Renovate auto-merges the PR if CI passes.
4. On merge to `main`, Woodpecker creates a release tag (`v{agent}-{webui}-am{agentmemory}`) if it does not already exist.
5. The tag push triggers a multi-arch build (`linux/amd64`, `linux/arm64`) and pushes to GHCR.

### Setup

1. Install the Renovate GitHub App on this repo, or run self-hosted Renovate.
2. Connect Woodpecker to this repo and set this secret in the Woodpecker UI:
   - `github_token` — GitHub PAT with `repo` and `write:packages` scopes.
3. On the next upstream release, the pipeline runs automatically.

### Image locations

| Registry | Image |
|----------|-------|
| Docker Hub (manual) | `ascensionoid/hermes-suite:{tag}` |
| GHCR (automated) | `ghcr.io/sunnysktsang/hermes-suite:{tag}` |

## Custom Additions

The `custom/` directory is merged into the image at build time. Use it for your own skills, tools, and background services.

| Path | Purpose |
|------|---------|
| `custom/requirements.txt` | Extra Python packages installed at build time |
| `custom/skills/<name>/` | Hermes skills copied into the image |
| `custom/entrypoint.d/*.sh` | Scripts available for custom startup handling |
| `custom/supervisord.d/*.conf` | Additional supervisord-managed services |

Included additions:

- `agentmemory/` — standalone AgentMemory image, local compose file, and Kubernetes manifest.
- `custom/skills/obsidian_sync/` — Obsidian sync helper skill copied into the Hermes image.
- `custom/bin/obsidian-sync-daemon.py` — periodic sync loop run inside the Hermes container.
- `custom/supervisord.d/obsidian-sync.conf` — supervisord program for Obsidian sync.

## Obsidian Sync

Obsidian sync runs inside the Hermes container using the official `obsidian-headless` CLI (`ob sync --continuous`).

Default environment:

```text
OBSIDIAN_VAULT_PATH=/workspace/obsidian
OBSIDIAN_SYNC_ENABLED=true
OBSIDIAN_SYNC_ONESHOT=false
```

Optional non-interactive setup:

```text
OBSIDIAN_EMAIL=<obsidian account email>
OBSIDIAN_PASSWORD=<obsidian account password>
OBSIDIAN_MFA=<one-time mfa code, if needed>
OBSIDIAN_REMOTE_VAULT=<remote vault id or name>
OBSIDIAN_E2EE_PASSWORD=<end-to-end encryption password, if needed>
OBSIDIAN_DEVICE_NAME=hermes-suite
OBSIDIAN_CONFIG_DIR=.obsidian
OBSIDIAN_SYNC_MODE=bidirectional
OBSIDIAN_CONFLICT_STRATEGY=merge
```

If credentials are not supplied, mount a preconfigured Obsidian/`ob` home into `/opt/data` and a vault at `/workspace/obsidian`.

Manual setup inside the running container:

```bash
ob login
cd /workspace/obsidian
ob sync-setup --vault "<vault id or name>"
ob sync --continuous
```

## AgentMemory

`agentmemory` is a long-running server and now lives outside the Hermes container.

Build/deploy image:

```text
ghcr.io/sunnysktsang/hermes-suite-agentmemory:<AGENTMEMORY_VERSION>
```

Local run:

```bash
cd agentmemory
docker compose --env-file versions.env up -d
curl http://localhost:3111/agentmemory/livez
```

Cluster run:

```bash
kubectl apply -f agentmemory/k8s.yaml
```

Hermes should connect to the service over REST through the AgentMemory MCP shim:

```yaml
mcp_servers:
  agentmemory:
    command: npx
    args: ["-y", "@agentmemory/mcp@0.9.26"]
    env:
      AGENTMEMORY_URL: http://agentmemory:3111
      AGENTMEMORY_TOOLS: all

memory:
  provider: agentmemory
```

## Docker/containerd runtime marker

The Dockerfile creates `/.dockerenv` intentionally:

```dockerfile
RUN touch /.dockerenv
```

`start.sh` already checks that file first in `is_docker()`, so this keeps the upstream script intact while forcing the Docker/containerd startup path.
