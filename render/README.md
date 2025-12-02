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
3. Enter: `ghcr.io/ferentin-net/service-edge:latest`
4. Configure environment variables
5. Add persistent disk

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `EDGE_CONTROL_PLANE_URL` | Yes | Control plane URL |
| `EDGE_ID` | Yes | Edge node ID |
| `EDGE_TENANT_ID` | Yes | Tenant ID |
| `EDGE_SITE_ID` | No | Site ID |
| `SPRING_PROFILES_ACTIVE` | No | Spring profile |

### Persistent Storage

Render supports one disk per service. The recommended approach is to mount a single disk and use subdirectories:

| Disk Mount | Size | Purpose |
|------------|------|---------|
| `/opt/ferentin/storage` | 2 GB | Combined storage |

The service edge will use:
- `/opt/ferentin/storage/certs` - Certificates
- `/opt/ferentin/storage/policies` - Policies

**Note**: You may need to configure environment variables to override default paths:

```bash
FERENTIN_CERTS_PATH=/opt/ferentin/storage/certs
FERENTIN_POLICIES_PATH=/opt/ferentin/storage/policies
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
