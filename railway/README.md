# Railway Deployment

Deploy Ferentin Service Edge to Railway.

## Prerequisites

- [Railway CLI](https://docs.railway.app/develop/cli)
- Railway account

## Quick Start

### Option 1: Deploy from Image

1. Create a new project in Railway dashboard
2. Add a new service from Docker image: `ghcr.io/ferentin-net/service-edge:latest`
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

# Set environment variables
railway variables set EDGE_CONTROL_PLANE_URL=https://cp.example.com
railway variables set EDGE_ID=edge-001
railway variables set EDGE_TENANT_ID=tenant-123
railway variables set SPRING_PROFILES_ACTIVE=production

# Deploy
railway up
```

## Environment Variables

Configure in Railway dashboard or CLI:

| Variable | Required | Description |
|----------|----------|-------------|
| `EDGE_CONTROL_PLANE_URL` | Yes | Control plane URL |
| `EDGE_ID` | Yes | Edge node ID |
| `EDGE_TENANT_ID` | Yes | Tenant ID |
| `EDGE_SITE_ID` | No | Site ID |
| `SPRING_PROFILES_ACTIVE` | No | Spring profile |

## Volumes

Railway supports persistent volumes through the dashboard:

1. Go to your service settings
2. Click "Add Volume"
3. Mount paths:
   - `/opt/ferentin/certs` - For certificates (required)
   - `/opt/ferentin/policies` - For policies (recommended)

## Custom Domain

1. Go to service settings
2. Click "Generate Domain" or "Add Custom Domain"
3. Configure DNS as instructed

## Monitoring

- View logs in Railway dashboard
- Use observability tab for metrics
- Configure alerts in project settings
