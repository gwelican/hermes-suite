# AgentMemory Service

Standalone `@agentmemory/agentmemory` image for Hermes.

## Image

Woodpecker builds and pushes:

```text
ghcr.io/sunnysktsang/hermes-suite-agentmemory:<AGENTMEMORY_VERSION>
ghcr.io/sunnysktsang/hermes-suite-agentmemory:latest
```

Pinned versions live in `agentmemory/versions.env`.

## Ports

| Port | Purpose |
|------|---------|
| `3111` | REST API and MCP proxy target |
| `3112` | streams |
| `3113` | viewer; upstream binds loopback by default |
| `9464` | metrics when enabled |

## Local run

```bash
cd agentmemory
docker compose --env-file versions.env up -d
curl http://localhost:3111/agentmemory/livez
```

## Kubernetes

Edit the image tag in `k8s.yaml` if needed, then apply:

```bash
kubectl apply -f agentmemory/k8s.yaml
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

If you bake `@agentmemory/mcp` into the Hermes image later, replace `command: npx` with `command: agentmemory` and `args: ["mcp"]`.
