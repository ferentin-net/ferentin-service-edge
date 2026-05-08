# Railway Deployment

Deploy Ferentin Service Edge to Railway.

## Prerequisites

- [Railway CLI](https://docs.railway.app/develop/cli)
- Railway account

## Quick Start

### Option 1: Deploy from Image

1. Create a new project in Railway dashboard
2. Add a new service from Docker image: `ghcr.io/ferentin-net/service-edge:<version>` (see [releases](https://github.com/ferentin-net/service-edge/releases))
3. Configure environment variables
4. Add persistent volumes

### Option 2: Deploy with CLI

```bash
# Login
railway login

# Initialize project
railway init

# Link to existing project
railway link

# Set environment variables (bootstrap auto-triggers on first run when
# ENROLLMENT_TOKEN is set and no certs exist on the volume)
railway variables set SPRING_PROFILES_ACTIVE=aws-secure
railway variables set ENROLLMENT_TOKEN=your-enrollment-token-here
railway variables set FERENTIN_KEY_PASSPHRASE=$(openssl rand -base64 48)
# Railway terminates TLS at their proxy — disable port filtering
railway variables set TLS_PORT_FILTERING_ENABLED=false

# Deploy
railway up
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9080 | HTTP | API endpoints, health checks |
| 9443 | HTTPS | TLS-encrypted API (enabled after certificate provisioning) |

The HTTPS listener on port 9443 activates automatically once server certificates are provisioned during bootstrap enrollment.

## What this exposes

Once enrolled, the Service Edge serves both LLM and MCP traffic on port **9443** (HTTPS):

| Capability | Endpoints |
|---|---|
| **LLM Proxy** | `/v1/chat/completions`, `/v1/messages`, `/v1/models`, `/v1/embeddings` |
| **MCP Gateway** | `/v1/mcp/{server-slug}` — Streamable HTTP transport, [2025-11-25 spec](https://modelcontextprotocol.io/specification/2025-11-25) |

What's active is controlled by the enrollment token's `capabilities` claim. Railway terminates TLS at their proxy; the container's 9080 HTTP listener handles forwarded traffic internally.

## Environment Variables

Configure in Railway dashboard or CLI:

| Variable | Required | Description |
|----------|----------|-------------|
| `ENROLLMENT_TOKEN` | Yes (first run) | Enrollment token from admin console (single-use, 15-min TTL). Bootstrap auto-triggers when this is set and no certs exist on the volume. |
| `FERENTIN_KEY_PASSPHRASE` | Yes | Passphrase for at-rest key encryption (min 32 chars). |
| `SPRING_PROFILES_ACTIVE` | No | Spring profile (default: `aws-secure`) |
| `TLS_PORT_FILTERING_ENABLED` | No | Set to `false` on Railway (proxy-terminated TLS). |
| `BOOTSTRAP_ENABLED` | No | Kill-switch only. Operators should not flip this in normal use. |
| `BOOTSTRAP_FORCE` | No | Force re-enrollment during recovery. |

> **Don't set `TENANT_ID`, `SITE_ID`, or `EDGE_ID`.** Identity is derived from the JWT claims at bootstrap.

## Volumes

Railway supports persistent volumes through the dashboard:

1. Go to your service settings
2. Click "Add Volume"
3. Mount paths:
   - `/opt/ferentin/certs` - For certificates (required)
   - `/opt/ferentin/policy` - For policies (recommended)

## Custom Domain

1. Go to service settings
2. Click "Generate Domain" or "Add Custom Domain"
3. Configure DNS as instructed

## Monitoring

- View logs in Railway dashboard
- Use observability tab for metrics
- Configure alerts in project settings
