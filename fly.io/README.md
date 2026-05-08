# Fly.io Deployment

Deploy Ferentin Service Edge to Fly.io.

## Prerequisites

- [Fly CLI](https://fly.io/docs/hands-on/install-flyctl/)
- Fly.io account

## Quick Start

```bash
# Login to Fly.io
fly auth login

# Launch the app (first time)
fly launch --no-deploy

# Set secrets (enrollment token from admin console)
fly secrets set ENROLLMENT_TOKEN=your-enrollment-token-here

# Create persistent volumes
fly volumes create service_edge_certs --size 1 --region iad
fly volumes create service_edge_policy --size 1 --region iad

# Deploy
fly deploy
```

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

What's active is controlled by the enrollment token's `capabilities` claim. Fly's edge proxy terminates TLS externally; the container's 9080 HTTP listener handles forwarded traffic internally.

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ENROLLMENT_TOKEN` | Yes (first run) | Enrollment token from admin console (single-use, 15-min TTL). Set via `fly secrets set`. Bootstrap auto-triggers when this is set and no certs exist on the volume. |
| `FERENTIN_KEY_PASSPHRASE` | Yes | Passphrase for at-rest key encryption (min 32 chars). Set via `fly secrets set`. |
| `SPRING_PROFILES_ACTIVE` | No | Spring profile (default: `aws-secure`) |
| `TLS_PORT_FILTERING_ENABLED` | No | Set to `false` for Fly (proxy-terminated TLS — see `fly.toml`). |
| `BOOTSTRAP_ENABLED` | No | Kill-switch only. Operators should not flip this in normal use. |
| `BOOTSTRAP_FORCE` | No | Force re-enrollment during recovery. |

> **Don't set `TENANT_ID`, `SITE_ID`, or `EDGE_ID`.** Identity is derived from the JWT claims at bootstrap.

### Secrets

```bash
# Set enrollment token (required for first-time setup)
fly secrets set ENROLLMENT_TOKEN=your-enrollment-token-here
```

### Scaling

```bash
# Scale to multiple regions
fly scale count 2 --region iad,lax

# Scale machine size
fly scale vm shared-cpu-2x
fly scale memory 2048
```

## Volumes

The app requires two persistent volumes:

| Volume | Path | Purpose |
|--------|------|---------|
| `service_edge_certs` | `/opt/ferentin/certs` | mTLS certificates |
| `service_edge_policy` | `/opt/ferentin/policy` | Policy bundles |

```bash
# List volumes
fly volumes list

# Extend volume
fly volumes extend <volume-id> --size 2
```

## Monitoring

```bash
# View logs
fly logs

# Check status
fly status

# SSH into machine
fly ssh console
```

## Custom Domain

```bash
# Add custom domain
fly certs add edge.example.com

# View certificates
fly certs list
```
