# Ferentin Service Edge

Deployment configurations for Ferentin Service Edge - a hardened LLM gateway container for edge deployments.

## Overview

Service Edge is a secure, production-ready container that provides:

- **OpenAI-compatible API** for LLM requests
- **MCP Gateway** for proxying MCP tool calls to upstream MCP servers with policy enforcement
- **Policy enforcement** for access control and data protection
- **Automatic certificate management** via bootstrap enrollment
- **Telemetry and audit logging** to the Ferentin control plane
- **Multi-provider routing** (OpenAI, Anthropic, Azure, Bedrock, Vertex AI, etc.)

## Container Images

| Registry | Image |
|----------|-------|
| GitHub Container Registry | `ghcr.io/ferentin-net/service-edge:<version>` |
| Amazon ECR | `089534985149.dkr.ecr.us-east-1.amazonaws.com/ferentin/service-edge:<version>` |

> **Pin to a specific version** (e.g., `service-edge:1.2.3`). Avoid using `:latest` in production — it makes deployments non-deterministic, complicates rollbacks, and may pull breaking changes. See [releases](https://github.com/ferentin-net/service-edge/releases) for available versions.

## Security Features

The Service Edge image is hardened with:

- Read-only root filesystem
- Non-root user (UID 1000)
- No package manager in runtime
- setuid/setgid bits removed
- Cosign-signed images
- Ubuntu Noble (glibc) base image

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

# Generate a passphrase for private key encryption (store this securely!)
export FERENTIN_KEY_PASSPHRASE=$(openssl rand -base64 48)
echo "Save this passphrase — if lost, the edge must re-enroll:"
echo "$FERENTIN_KEY_PASSPHRASE"

# Run with bootstrap enrollment
docker run -d \
  --name service-edge \
  --read-only \
  -v service-edge-certs:/opt/ferentin/certs:rw \
  -v service-edge-policy:/opt/ferentin/policy:rw \
  --tmpfs /opt/ferentin/logs:rw,uid=1000,gid=1000,noexec,nosuid,size=100m \
  --tmpfs /opt/ferentin/data:rw,uid=1000,gid=1000,noexec,nosuid,size=50m \
  --tmpfs /opt/ferentin/tmp:rw,uid=1000,gid=1000,noexec,nosuid,size=100m \
  -p 9443:9443 \
  -e BOOTSTRAP_ENABLED=true \
  -e ENROLLMENT_TOKEN=your-enrollment-token-here \
  -e FERENTIN_KEY_PASSPHRASE="$FERENTIN_KEY_PASSPHRASE" \
  -e SPRING_PROFILES_ACTIVE=aws-secure \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  ghcr.io/ferentin-net/service-edge:1.0.0  # Pin to a specific version
```

### 3. Verify Enrollment

```bash
# Check health endpoint (internal port)
curl http://localhost:9080/actuator/health

# Test LLM API over TLS (after enrollment completes)
curl https://localhost:9443/v1/models
```

## Ports

| Port | Protocol | Purpose | Exposure |
|------|----------|---------|----------|
| 9443 | HTTPS | LLM API endpoints (primary) | External |
| 9080 | HTTP | Health checks, actuator only | Internal only |

Port 9443 is the primary API port for all LLM traffic. It activates automatically once server certificates are provisioned during bootstrap enrollment. Port 9080 is restricted to health checks and actuator endpoints — LLM API endpoints (`/v1/chat/completions`, `/v1/messages`, etc.) are blocked on this port.

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

### Multi-Instance and TLS

For high availability, deploy multiple Service Edge instances behind a load balancer. See [TLS.md](TLS.md) for:
- How server and client certificates work
- Load balancer configuration (Nginx, HAProxy, Caddy, Envoy, ALB)
- End-to-end encryption setup
- Multi-instance Docker Compose example

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

### Security Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `FERENTIN_KEY_PASSPHRASE` | **Yes** | - | Passphrase for private key encryption at rest (minimum 32 characters). Protects `client.key` and `server.key` on disk using AES-256-GCM. Generate **once** with `openssl rand -base64 48` and store securely. Must be the same value on every restart — if lost, the edge must re-enroll. |
| `FERENTIN_KEY_PASSPHRASE_OLD` | No | - | Set alongside `FERENTIN_KEY_PASSPHRASE` to rotate the passphrase. See [Passphrase Rotation](#passphrase-rotation). |

### TLS Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TLS_ENABLED` | No | `true` | Enable HTTPS listener on port 9443 |
| `TLS_PORT` | No | `9443` | HTTPS listener port |

### Runtime Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JAVA_OPTS` | No | See docs | Additional JVM options |
| `ENABLE_VIRTUAL_THREADS` | No | `false` | Enable Java 25 virtual threads |
| `EDGE_CA_BUNDLE` | No | - | Custom CA bundle (PEM format) |

## Health Checks

| Endpoint | Purpose |
|----------|---------|
| TCP 9080 | Basic liveness |
| `/actuator/health` | Full health status |
| `/actuator/health/liveness` | Kubernetes liveness probe |
| `/actuator/health/readiness` | Kubernetes readiness probe |

## API Endpoints

Once enrolled, Service Edge exposes APIs on port **9443** (TLS). Which capabilities are active depends on the enrollment token — the `capabilities` claim controls whether LLM and/or MCP endpoints are enabled.

### OpenAI-Compatible

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completions API |
| `/v1/models` | GET | List available models |
| `/v1/embeddings` | POST | Embeddings API |

### Anthropic-Compatible

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/messages` | POST | Messages API (Claude) |

### MCP Gateway

The MCP Gateway proxies [MCP (Model Context Protocol)](https://modelcontextprotocol.io) requests to upstream MCP servers with tenant-scoped policy enforcement, session management, and audit logging.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/mcp/{server-slug}` | POST | MCP JSON-RPC 2.0 endpoint (Streamable HTTP transport) |
| `/.well-known/oauth-protected-resource/v1/mcp` | GET | OAuth2 Protected Resource Metadata ([RFC 9728](https://www.rfc-editor.org/rfc/rfc9728)) |
| `/v1/mcp/.well-known/oauth-protected-resource` | GET | PRM discovery (alternative path) |

**Route pattern**: `https://<edge-host>:9443/v1/mcp/{server-slug}`

- `{server-slug}` identifies the upstream MCP server (e.g., `github`, `slack`, `stripe`)
- Available server slugs are defined in the tenant's policy bundle
- Requires a Bearer token with `mcp` scope (issued by the Ferentin authorization server)
- Supports `MCP-Session-Id` header for session continuity

**Supported JSON-RPC methods**: `initialize`, `tools/list`, `tools/call`, `ping`, `notifications/initialized`

**Example — List tools on a GitHub MCP server**:
```bash
curl -X POST https://localhost:9443/v1/mcp/github \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

**Example — Call a tool**:
```bash
curl -X POST https://localhost:9443/v1/mcp/github \
  -H "Authorization: Bearer $TOKEN" \
  -H "MCP-Session-Id: $SESSION_ID" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_user_profile","arguments":{}}}'
```

### Capability Activation

LLM and MCP capabilities are controlled by the enrollment token, not environment variables. When creating an enrollment token in the admin console, select which capabilities to enable:

| Capability | Enrollment Claim | Endpoints Enabled |
|------------|-----------------|-------------------|
| `llm` | `capabilities.llm: true` | `/v1/chat/completions`, `/v1/messages`, `/v1/models`, `/v1/embeddings` |
| `mcp` | `capabilities.mcp: true` | `/v1/mcp/{server-slug}`, MCP discovery endpoints |

## Passphrase Rotation

To change the `FERENTIN_KEY_PASSPHRASE` without re-enrolling the edge:

1. Generate a new passphrase:
   ```bash
   export NEW_PASSPHRASE=$(openssl rand -base64 48)
   echo "New passphrase (store securely): $NEW_PASSPHRASE"
   ```

2. Set both the old and new passphrases, then restart:

   **Docker:**
   ```bash
   docker run -d \
     -e FERENTIN_KEY_PASSPHRASE="$NEW_PASSPHRASE" \
     -e FERENTIN_KEY_PASSPHRASE_OLD="$OLD_PASSPHRASE" \
     ...
   ```

   **Kubernetes:**
   ```bash
   kubectl create secret generic service-edge-secrets \
     --from-literal=key-passphrase="$NEW_PASSPHRASE" \
     --from-literal=key-passphrase-old="$OLD_PASSPHRASE" \
     --dry-run=client -o yaml | kubectl apply -f -
   kubectl rollout restart deployment/service-edge
   ```

   **Fly.io:**
   ```bash
   fly secrets set FERENTIN_KEY_PASSPHRASE="$NEW_PASSPHRASE" FERENTIN_KEY_PASSPHRASE_OLD="$OLD_PASSPHRASE"
   ```

3. On startup, the edge will:
   - Decrypt `client.key` and `server.key` with the old passphrase
   - Re-encrypt both with the new passphrase
   - Atomically replace the files on disk
   - Continue normal operation with the new passphrase

4. After confirming the edge is running, **remove** `FERENTIN_KEY_PASSPHRASE_OLD` from the environment and restart once more. This is a cleanup step — the edge will operate normally without it.

**Important:**
- The new passphrase must be at least 32 characters
- The new passphrase must differ from the old one
- If rotation fails (e.g., wrong old passphrase), the original files are left intact
- Neither passphrase is logged

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
- [Contact Support](mailto:support@ferentin.com)

## License

Proprietary - Ferentin
