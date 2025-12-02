# Ferentin Service Edge

Deployment configurations for Ferentin Service Edge - a hardened, combined edge-agent and edge-runtime container for LLM gateway deployments.

## Container Images

| Registry | Image |
|----------|-------|
| GitHub Container Registry | `ghcr.io/ferentin-net/service-edge:latest` |
| Amazon ECR | `089534985149.dkr.ecr.us-east-1.amazonaws.com/ferentin/service-edge:latest` |

## Security Features

The Service Edge image is hardened with:

- Read-only root filesystem
- Non-root user (UID 1000)
- No package manager in runtime
- setuid/setgid bits removed
- Cosign-signed images
- Minimal Alpine base image

## Quick Start

### Docker

```bash
# Create persistent volumes
docker volume create service-edge-certs
docker volume create service-edge-policies

# Run with read-only filesystem
docker run -d \
  --name service-edge \
  --read-only \
  -v service-edge-certs:/opt/ferentin/certs:rw \
  -v service-edge-policies:/opt/ferentin/policies:rw \
  --tmpfs /opt/ferentin/logs:rw,noexec,nosuid,size=100m \
  --tmpfs /opt/ferentin/data:rw,noexec,nosuid,size=50m \
  --tmpfs /opt/ferentin/tmp:rw,noexec,nosuid,size=100m \
  -p 9080:9080 \
  -e EDGE_CONTROL_PLANE_URL=https://cp.example.com \
  -e EDGE_ID=edge-001 \
  -e EDGE_TENANT_ID=tenant-123 \
  ghcr.io/ferentin-net/service-edge:latest
```

### Docker Compose

```bash
cd docker-compose
cp .env.example .env
# Edit .env with your configuration
docker-compose up -d
```

### Kubernetes

```bash
cd kubernetes
kubectl apply -f namespace.yaml
kubectl apply -f .
```

### Helm

```bash
helm install service-edge ./helm/service-edge \
  --set config.controlPlaneUrl=https://cp.example.com \
  --set config.edgeId=edge-001 \
  --set config.tenantId=tenant-123
```

## Deployment Guides

| Platform | Guide |
|----------|-------|
| Docker Compose | [docker-compose/README.md](docker-compose/README.md) |
| Kubernetes | [kubernetes/README.md](kubernetes/README.md) |
| Helm | [helm/service-edge/README.md](helm/service-edge/README.md) |
| AWS ECS | [aws-ecs/README.md](aws-ecs/README.md) |
| Fly.io | [fly.io/README.md](fly.io/README.md) |
| Railway | [railway/README.md](railway/README.md) |
| Render | [render/README.md](render/README.md) |

## Required Volumes

| Path | Purpose | Type | Persistence |
|------|---------|------|-------------|
| `/opt/ferentin/certs` | mTLS certificates | Persistent | **Required** |
| `/opt/ferentin/policies` | Policy bundles | Persistent | Recommended |
| `/opt/ferentin/logs` | Application logs | tmpfs/Persistent | Optional |
| `/opt/ferentin/data` | Runtime data | tmpfs/Persistent | Optional |
| `/opt/ferentin/tmp` | Java temp files | tmpfs | Ephemeral |

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `EDGE_CONTROL_PLANE_URL` | Yes | - | Control plane URL |
| `EDGE_ID` | Yes | - | Unique edge node ID |
| `EDGE_TENANT_ID` | Yes | - | Tenant ID |
| `EDGE_SITE_ID` | No | - | Site ID for multi-site |
| `SPRING_PROFILES_ACTIVE` | No | `production` | Spring profile |
| `JAVA_OPTS` | No | See docs | JVM options |
| `ENABLE_VIRTUAL_THREADS` | No | `false` | Enable virtual threads |

## Health Checks

| Endpoint | Purpose |
|----------|---------|
| TCP 9080 | Basic liveness |
| `/actuator/health` | Full health status |
| `/actuator/health/liveness` | Kubernetes liveness |
| `/actuator/health/readiness` | Kubernetes readiness |

## Migration from edge-runtime + edge-agent

Service Edge replaces the separate `edge-runtime` and `edge-agent` containers with a single unified container.

### Before (deprecated)
```yaml
services:
  edge-runtime:
    image: ghcr.io/ferentin-net/edge-runtime:1.0.0
    ports:
      - "9081:9081"
  edge-agent:
    image: ghcr.io/ferentin-net/edge-agent:1.0.0
    ports:
      - "9080:9080"
```

### After
```yaml
services:
  service-edge:
    image: ghcr.io/ferentin-net/service-edge:1.0.0
    ports:
      - "9080:9080"  # Single port for all endpoints
```

## Support

- [Documentation](https://github.com/ferentin-net/ferentin-platform/blob/main/edge-node/docker/README.md)
- [Issues](https://github.com/ferentin-net/ferentin-service-edge/issues)
- [Ferentin Platform](https://github.com/ferentin-net/ferentin-platform)

## License

Proprietary - Ferentin
