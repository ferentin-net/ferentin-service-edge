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

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SPRING_PROFILES_ACTIVE` | No | Spring profile (default: `aws-secure`) |
| `BOOTSTRAP_ENABLED` | No | Enable bootstrap (default: `true`) |
| `ENROLLMENT_TOKEN` | Yes | Enrollment token from admin console |

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
