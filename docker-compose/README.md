# Docker Compose Deployment

Deploy Ferentin Service Edge using Docker Compose.

## Prerequisites

1. **Obtain an enrollment token** from the Ferentin admin console
2. Docker and Docker Compose installed

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Add your enrollment token to .env
nano .env

# Fix volume permissions (required for non-root container)
docker volume create service-edge-certs
docker volume create service-edge-policy
docker run --rm \
  -v service-edge-certs:/opt/ferentin/certs \
  -v service-edge-policy:/opt/ferentin/policy \
  alpine:latest chown -R 1000:1000 /opt/ferentin/certs /opt/ferentin/policy

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
# Required: Enrollment token from admin console (single-use, 15-min TTL)
ENROLLMENT_TOKEN=your-token-here

# Required: Passphrase for at-rest key encryption (min 32 chars)
# Generate with: openssl rand -base64 48
FERENTIN_KEY_PASSPHRASE=

# Required: Spring profile (determines control plane URL)
# - aws-secure: Production (https://cp.ferentin.net)
# - nginx: Local development (https://cp.local.ferentin.test)
SPRING_PROFILES_ACTIVE=aws-secure

# Required: Image version — pin to a specific release
# See https://github.com/ferentin-net/service-edge/releases
SERVICE_EDGE_VERSION=0.4.1
```

> **Don't set `TENANT_ID`, `SITE_ID`, or `EDGE_ID`.** They're derived from the enrollment token's JWT claims at bootstrap. Any env var that disagrees with the token aborts startup.

## Enrollment Process

On first startup with a valid `ENROLLMENT_TOKEN` and no certs on the persistent volume, the service-edge:

1. **Connects** to the control plane (URL determined by Spring profile).
2. **Exchanges** the bootstrap token for long-lived mTLS client cert + HTTPS server cert (both signed by the Ferentin CA).
3. **Persists** the certs and the edge config (tenant ID, site ID, edge ID, edge type — all from JWT claims) to `/opt/ferentin/certs`.
4. **Downloads** the initial policy bundle to `/opt/ferentin/policy`.
5. **Binds** the HTTPS listener on port 9443 once the server cert is in place.

On subsequent restarts the token is harmless — the runner detects valid certs and short-circuits.

## After Enrollment

You can leave `ENROLLMENT_TOKEN` in the `.env` (it's a no-op on warm restart) or remove it. The edge uses the persisted certs.

## Persistent Data

The following volumes are created:

| Volume | Purpose |
|--------|---------|
| `service-edge-certs` | mTLS certificates (persistent) |
| `service-edge-policy` | Policy bundles (persistent) |

Logs, data, and tmp directories use tmpfs (ephemeral).

## Ports

| Port | Protocol | Purpose | Exposure |
|------|----------|---------|----------|
| 9443 | HTTPS | LLM and MCP API endpoints (primary) | External |
| 9080 | HTTP | Health checks, actuator only | Internal only |

Port 9443 is the primary API port for all LLM and MCP traffic. It activates automatically once server certificates are provisioned during bootstrap enrollment. Port 9080 is restricted to health checks — LLM API endpoints are blocked on this port.

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

## Re-enrollment

If you need to re-enroll (e.g., certificates expired or revoked):

1. Obtain a new enrollment token from admin console
2. Update `.env` with the new token
3. Set `BOOTSTRAP_FORCE=true` to bypass the on-disk-cert short-circuit
4. Restart: `docker-compose up -d`
5. After successful re-enrollment, remove `BOOTSTRAP_FORCE` from the env

## Production Configuration

For production, consider:

1. **External volumes**: Mount persistent storage for certs/policy
2. **Logging driver**: Configure log rotation or external logging
3. **Network**: Use overlay network for multi-host setups
4. **Secrets**: Use Docker secrets for the enrollment token

See `docker-compose.prod.yml` for production overrides.
