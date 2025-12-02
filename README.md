# Ferentin Service Edge

Deployment configurations for Ferentin Service Edge - a hardened LLM gateway container for edge deployments.

## Overview

Service Edge is a secure, production-ready container that provides:

- **OpenAI-compatible API** for LLM requests
- **Policy enforcement** for access control and data protection
- **Automatic certificate management** via bootstrap enrollment
- **Telemetry and audit logging** to the Ferentin control plane
- **Multi-provider routing** (OpenAI, Anthropic, Azure, Bedrock, Vertex AI, etc.)

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

### 1. Get an Enrollment Token

1. Log into the [Ferentin Admin Console](https://console.ferentin.net)
2. Navigate to **Edge Nodes** > **Add Edge Node**
3. Copy the enrollment token

### 2. Deploy with Docker

```bash
# Create persistent volumes
docker volume create service-edge-certs
docker volume create service-edge-policy

# Run with bootstrap enrollment
docker run -d \
  --name service-edge \
  --read-only \
  -v service-edge-certs:/opt/ferentin/certs:rw \
  -v service-edge-policy:/opt/ferentin/policy:rw \
  --tmpfs /opt/ferentin/logs:rw,uid=1000,gid=1000,noexec,nosuid,size=100m \
  --tmpfs /opt/ferentin/data:rw,uid=1000,gid=1000,noexec,nosuid,size=50m \
  --tmpfs /opt/ferentin/tmp:rw,uid=1000,gid=1000,noexec,nosuid,size=100m \
  -p 9080:9080 \
  -p 9443:9443 \
  -e BOOTSTRAP_ENABLED=true \
  -e ENROLLMENT_TOKEN=your-enrollment-token-here \
  -e SPRING_PROFILES_ACTIVE=aws-secure \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  ghcr.io/ferentin-net/service-edge:latest
```

### 3. Verify Enrollment

```bash
# Check health endpoint
curl http://localhost:9080/actuator/health

# Test LLM API (after enrollment completes)
curl http://localhost:9080/v1/models
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9080 | HTTP | API endpoints, health checks |
| 9443 | HTTPS | TLS-encrypted API (enabled after certificate provisioning) |

The HTTPS listener on port 9443 activates automatically once server certificates are provisioned during bootstrap enrollment.

## Deployment Guides

| Platform | Guide |
|----------|-------|
| Docker Compose | [docker-compose/](docker-compose/) |
| Kubernetes | [kubernetes/](kubernetes/) |
| Helm | [helm/service-edge/](helm/service-edge/) |
| AWS ECS | [aws-ecs/](aws-ecs/) |
| Fly.io | [fly.io/](fly.io/) |
| Railway | [railway/](railway/) |
| Render | [render/](render/) |

## Required Volumes

| Path | Purpose | Type | Persistence |
|------|---------|------|-------------|
| `/opt/ferentin/certs` | mTLS certificates | Persistent | **Required** |
| `/opt/ferentin/policy` | Policy bundles | Persistent | Recommended |
| `/opt/ferentin/logs` | Application logs | tmpfs/Persistent | Optional |
| `/opt/ferentin/data` | Runtime data | tmpfs/Persistent | Optional |
| `/opt/ferentin/tmp` | Java temp files | tmpfs | Ephemeral |

## Environment Variables

### Bootstrap Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BOOTSTRAP_ENABLED` | Yes (first run) | `false` | Enable bootstrap enrollment |
| `ENROLLMENT_TOKEN` | Yes (first run) | - | JWT enrollment token from admin console |
| `SPRING_PROFILES_ACTIVE` | No | `aws-secure` | Spring profile for configuration |

### TLS Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TLS_ENABLED` | No | `true` | Enable HTTPS listener on port 9443 |
| `TLS_PORT` | No | `9443` | HTTPS listener port |

### Runtime Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JAVA_OPTS` | No | See docs | Additional JVM options |
| `ENABLE_VIRTUAL_THREADS` | No | `false` | Enable Java 21 virtual threads |
| `EDGE_CA_BUNDLE` | No | - | Custom CA bundle (PEM format) |

## Health Checks

| Endpoint | Purpose |
|----------|---------|
| TCP 9080 | Basic liveness |
| `/actuator/health` | Full health status |
| `/actuator/health/liveness` | Kubernetes liveness probe |
| `/actuator/health/readiness` | Kubernetes readiness probe |

## API Endpoints

Once enrolled, Service Edge exposes LLM provider-compatible APIs:

### OpenAI-Compatible

| Endpoint | Description |
|----------|-------------|
| `POST /v1/chat/completions` | Chat completions API |
| `GET /v1/models` | List available models |
| `POST /v1/embeddings` | Embeddings API |

### Anthropic-Compatible

| Endpoint | Description |
|----------|-------------|
| `POST /v1/messages` | Messages API (Claude) |

## Troubleshooting

### Container fails to start with "directory not mounted"

Ensure all required volumes are mounted:

```bash
docker run --read-only \
  -v service-edge-certs:/opt/ferentin/certs:rw \
  -v service-edge-policy:/opt/ferentin/policy:rw \
  --tmpfs /opt/ferentin/logs:rw,uid=1000,gid=1000 \
  --tmpfs /opt/ferentin/data:rw,uid=1000,gid=1000 \
  --tmpfs /opt/ferentin/tmp:rw,uid=1000,gid=1000 \
  ...
```

### Container fails with "directory not writable"

Fix volume permissions for the non-root user (UID 1000):

```bash
docker run --rm \
  -v service-edge-certs:/opt/ferentin/certs \
  -v service-edge-policy:/opt/ferentin/policy \
  alpine:latest chown -R 1000:1000 /opt/ferentin/certs /opt/ferentin/policy
```

### Bootstrap enrollment fails

1. Verify the enrollment token is valid (not expired)
2. Check network connectivity to the Ferentin control plane
3. Review logs: `docker logs service-edge`

### HTTPS listener not starting

The TLS listener requires server certificates in `/opt/ferentin/certs`:
- `server.crt` - Server certificate
- `server.key` - Server private key

These are automatically provisioned during bootstrap enrollment.

## Support

- [Documentation](https://docs.ferentin.net)
- [Issues](https://github.com/ferentin-net/ferentin-service-edge/issues)
- [Contact Support](mailto:support@ferentin.net)

## License

Proprietary - Ferentin
