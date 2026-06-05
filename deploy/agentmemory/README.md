# AgentMemory Service

Standalone `@agentmemory/agentmemory` image for Hermes.

## Image

GitHub Actions builds and pushes:

```text
ghcr.io/gwelican/hermes-suite-agentmemory:<suite_version>
ghcr.io/gwelican/hermes-suite-agentmemory:<agentmemory_version>
ghcr.io/gwelican/hermes-suite-agentmemory:latest
```

Pinned versions live in:

```text
config/versions.env
```

## Ports

| Port | Purpose |
|------|---------|
| `3111` | REST API and MCP proxy target |
| `3112` | streams |
| `3113` | viewer; upstream binds loopback by default |
| `9464` | metrics when enabled |

## Local run

```bash
set -a
. ./config/versions.env
set +a
docker compose -f deploy/agentmemory/compose.yaml up -d
curl http://localhost:3111/agentmemory/livez
```

## Kubernetes

Edit the image tag in `deploy/agentmemory/k8s.yaml` if needed, then apply:

```bash
kubectl apply -f deploy/agentmemory/k8s.yaml
```

Hermes should point at the cluster service:

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
