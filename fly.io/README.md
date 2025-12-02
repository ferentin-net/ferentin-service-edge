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

# Set secrets
fly secrets set \
  EDGE_CONTROL_PLANE_URL=https://cp.example.com \
  EDGE_ID=edge-001 \
  EDGE_TENANT_ID=tenant-123

# Create persistent volumes
fly volumes create service_edge_certs --size 1 --region iad
fly volumes create service_edge_policies --size 1 --region iad

# Deploy
fly deploy
```

## Configuration

### Secrets

```bash
fly secrets set EDGE_CONTROL_PLANE_URL=https://cp.example.com
fly secrets set EDGE_ID=edge-001
fly secrets set EDGE_TENANT_ID=tenant-123
fly secrets set EDGE_SITE_ID=site-001  # Optional
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
| `service_edge_policies` | `/opt/ferentin/policies` | Policy bundles |

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
