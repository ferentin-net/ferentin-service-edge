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
railway variables set SPRING_PROFILES_ACTIVE=aws-secure
railway variables set BOOTSTRAP_ENABLED=true
railway variables set ENROLLMENT_TOKEN=your-enrollment-token-here

# Deploy
railway up
```

## Environment Variables

Configure in Railway dashboard or CLI:

| Variable | Required | Description |
|----------|----------|-------------|
| `SPRING_PROFILES_ACTIVE` | No | Spring profile (default: `aws-secure`) |
| `BOOTSTRAP_ENABLED` | Yes | Set to `true` for first-time enrollment |
| `ENROLLMENT_TOKEN` | Yes | Enrollment token from admin console |

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
