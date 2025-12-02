# Docker Compose Deployment

Deploy Ferentin Service Edge using Docker Compose.

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Edit configuration
nano .env

# Start the service
docker-compose up -d

# Check logs
docker-compose logs -f

# Stop the service
docker-compose down
```

## Configuration

Edit `.env` file with your settings:

```bash
# Required
EDGE_CONTROL_PLANE_URL=https://cp.example.com
EDGE_ID=edge-001
EDGE_TENANT_ID=tenant-123

# Optional
SPRING_PROFILES_ACTIVE=production
```

## Persistent Data

The following volumes are created:

| Volume | Purpose |
|--------|---------|
| `service-edge-certs` | mTLS certificates (persistent) |
| `service-edge-policies` | Policy bundles (persistent) |

Logs, data, and tmp directories use tmpfs (ephemeral).

## Health Check

```bash
# Check container health
docker-compose ps

# Manual health check
curl http://localhost:9080/actuator/health
```

## Logs

```bash
# Follow logs
docker-compose logs -f service-edge

# Last 100 lines
docker-compose logs --tail=100 service-edge
```

## Upgrade

```bash
# Pull new image
docker-compose pull

# Restart with new image
docker-compose up -d
```

## Production Configuration

For production, consider:

1. **External volumes**: Mount persistent storage for certs/policies
2. **Logging driver**: Configure log rotation or external logging
3. **Network**: Use overlay network for multi-host setups
4. **Secrets**: Use Docker secrets for sensitive data

See `docker-compose.prod.yml` for production overrides.
