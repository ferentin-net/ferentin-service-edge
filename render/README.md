# Render.com Deployment

Deploy Ferentin Service Edge to Render.

## Prerequisites

- Render account

## Quick Start

### Option 1: Deploy with Blueprint

1. Fork this repository
2. Create a new Blueprint in Render dashboard
3. Connect your forked repository
4. Render will detect `render.yaml` and configure the service

### Option 2: Manual Setup

1. Create a new Web Service in Render
2. Select "Deploy an existing image from a registry"
3. Enter: `ghcr.io/ferentin-net/service-edge:<version>` (see [releases](https://github.com/ferentin-net/service-edge/releases))
4. Configure environment variables
5. Add persistent disk

## Configuration

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9080 | HTTP | API endpoints, health checks |
| 9443 | HTTPS | TLS-encrypted API (enabled after certificate provisioning) |

The HTTPS listener on port 9443 activates automatically once server certificates are provisioned during bootstrap enrollment.

### What this exposes

Once enrolled, the Service Edge serves both LLM and MCP traffic on port **9443** (HTTPS):

| Capability | Endpoints |
|---|---|
| **LLM Proxy** | `/v1/chat/completions`, `/v1/messages`, `/v1/models`, `/v1/embeddings` |
| **MCP Gateway** | `/v1/mcp/{server-slug}` — Streamable HTTP transport, [2025-11-25 spec](https://modelcontextprotocol.io/specification/2025-11-25) |

What's active is controlled by the enrollment token's `capabilities` claim. Render terminates TLS at their proxy; the container's 9080 HTTP listener handles forwarded traffic internally.

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ENROLLMENT_TOKEN` | Yes (first run) | Enrollment token from admin console (single-use, 15-min TTL). Bootstrap auto-triggers when this is set and no certs exist on the volume. |
| `FERENTIN_KEY_PASSPHRASE` | Yes | Passphrase for at-rest key encryption (min 32 chars). |
| `SPRING_PROFILES_ACTIVE` | No | Spring profile (default: `aws-secure`) |
| `TLS_PORT_FILTERING_ENABLED` | No | Set to `false` on Render (proxy-terminated TLS). |
| `BOOTSTRAP_ENABLED` | No | Kill-switch only. Operators should not flip this in normal use. |
| `BOOTSTRAP_FORCE` | No | Force re-enrollment during recovery. |

> **Don't set `TENANT_ID`, `SITE_ID`, or `EDGE_ID`.** Identity is derived from the JWT claims at bootstrap.

### Persistent Storage

Render supports one disk per service. The recommended approach is to mount a single disk and use subdirectories:

| Disk Mount | Size | Purpose |
|------------|------|---------|
| `/opt/ferentin/storage` | 2 GB | Combined storage |

The service edge will use:
- `/opt/ferentin/storage/certs` - Certificates
- `/opt/ferentin/storage/policy` - Policies

**Note**: You may need to configure environment variables to override default paths:

```bash
MTLS_CERT_PATH=/opt/ferentin/storage/certs/client.crt
MTLS_KEY_PATH=/opt/ferentin/storage/certs/client.key
MTLS_CA_PATH=/opt/ferentin/storage/certs/ca.crt
POLICY_BUNDLE_DIR=/opt/ferentin/storage/policy
```

## Scaling

### Plan Options

| Plan | CPU | Memory |
|------|-----|--------|
| Starter | 0.5 | 512 MB |
| Standard | 1 | 2 GB |
| Pro | 2 | 4 GB |

Upgrade plan in service settings.

### Auto-Scaling

Render supports auto-scaling on Pro plan:

1. Go to service settings
2. Enable auto-scaling
3. Configure min/max instances

## Custom Domain

1. Go to service settings
2. Add custom domain
3. Configure DNS as instructed
4. Render provides free TLS certificates

## Monitoring

- View logs in Render dashboard
- Configure log drains for external logging
- Set up health check alerts
