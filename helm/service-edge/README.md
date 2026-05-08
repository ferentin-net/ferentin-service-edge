# Service Edge Helm Chart

Helm chart for deploying Ferentin Service Edge to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Enrollment token from [Ferentin Admin Console](https://admin.ferentin.net)

## Quick Start

### 1. Get an Enrollment Token

1. Log into the [Ferentin Admin Console](https://admin.ferentin.net)
2. Navigate to **Edge Nodes** > **Add Edge Node**
3. Copy the enrollment token

### 2. Create Kubernetes Secret

```bash
kubectl create secret generic service-edge-enrollment \
  --from-literal=ENROLLMENT_TOKEN=your-enrollment-token-here
```

### 3. Install the Chart

```bash
helm install service-edge ./service-edge \
  --set bootstrap.existingSecret=service-edge-enrollment
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9080 | HTTP | API endpoints, health checks |
| 9443 | HTTPS | TLS-encrypted API (enabled after certificate provisioning) |

The HTTPS listener on port 9443 activates automatically once server certificates are provisioned during bootstrap enrollment.

## What this exposes

Once enrolled, the Service Edge serves both LLM and MCP traffic on port **9443** (HTTPS). What's active depends on the enrollment token's `capabilities` claim:

| Capability | Endpoints |
|---|---|
| **LLM Proxy** | `/v1/chat/completions`, `/v1/messages`, `/v1/models`, `/v1/embeddings` |
| **MCP Gateway** | `/v1/mcp/{server-slug}` (Streamable HTTP, [2025-11-25 spec](https://modelcontextprotocol.io/specification/2025-11-25)), `/.well-known/oauth-protected-resource/v1/mcp` |

The MCP Gateway proxies tool calls to upstream MCP servers (private, customer-network MCP servers and/or SaaS / cloud-hosted MCP servers) with tenant-scoped policy enforcement and per-tool audit logging.

## Configuration

### Bootstrap Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `config.bootstrap.enabled` | `true` | Kill-switch only. Set to `false` to suppress bootstrap entirely. Bootstrap auto-triggers when `ENROLLMENT_TOKEN` is present and no certs are on the cert PVC — no need to flip this in normal use. |
| `config.bootstrap.force` | `false` | Force re-enrollment even when valid certs exist on the cert PVC. Used during recovery scenarios. |
| `config.bootstrap.enrollmentToken` | `""` | Inline token. Prefer `bootstrap.existingSecret` in production. |
| `bootstrap.existingSecret` | `""` | Name of secret containing `ENROLLMENT_TOKEN` and `key-passphrase`. |
| `config.springProfile` | `aws-secure` | Spring profile (`aws-secure` for prod, `nginx` for local dev). |

> **Don't set `TENANT_ID`, `SITE_ID`, or `EDGE_ID`.** Tenant / site / edge identity is derived from the JWT claims (`tid`, `site_id`, `edge_id`, `edge_type`) at bootstrap; a mismatch with the token aborts startup.

### TLS Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `config.tls.enabled` | `true` | Enable HTTPS listener on port 9443 |
| `config.tls.port` | `9443` | HTTPS listener port |

### Image

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `ghcr.io/ferentin-net/service-edge` | Image repository |
| `image.tag` | `0.4.0` | Image tag — pin to a specific release; see [versions](https://github.com/orgs/ferentin-net/packages/container/package/service-edge) |
| `image.pullPolicy` | `IfNotPresent` | Pull policy |

### Resources

| Parameter | Default | Description |
|-----------|---------|-------------|
| `resources.requests.cpu` | `250m` | CPU request |
| `resources.requests.memory` | `512Mi` | Memory request |
| `resources.limits.cpu` | `1000m` | CPU limit |
| `resources.limits.memory` | `1Gi` | Memory limit |

### Persistence

| Parameter | Default | Description |
|-----------|---------|-------------|
| `persistence.certs.enabled` | `true` | Enable certs PVC |
| `persistence.certs.size` | `100Mi` | Certs volume size |
| `persistence.policies.enabled` | `true` | Enable policies PVC |
| `persistence.policies.size` | `100Mi` | Policies volume size |

### Service

| Parameter | Default | Description |
|-----------|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `9080` | HTTP service port |
| `service.tlsPort` | `9443` | HTTPS service port |

### Ingress

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.className` | `""` | Ingress class |
| `ingress.hosts` | `[]` | Ingress hosts |

### Optional Runtime Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `config.enableVirtualThreads` | `false` | Enable Java 25 virtual threads |
| `config.javaOpts` | `""` | Custom JVM options |
| `config.caBundle` | `""` | Custom CA bundle (PEM format) |

## Examples

### Basic Installation with Secret

```bash
# Create secret with enrollment token
kubectl create secret generic service-edge-enrollment \
  --from-literal=ENROLLMENT_TOKEN=your-enrollment-token-here

# Install chart
helm install service-edge ./service-edge \
  --set bootstrap.existingSecret=service-edge-enrollment
```

### With Custom Resources

```bash
helm install service-edge ./service-edge \
  --set bootstrap.existingSecret=service-edge-enrollment \
  --set resources.limits.memory=2Gi \
  --set resources.limits.cpu=2000m
```

### With Ingress

```bash
helm install service-edge ./service-edge \
  --set bootstrap.existingSecret=service-edge-enrollment \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=edge.example.com \
  --set ingress.hosts[0].paths[0].path=/
```

### Using values.yaml

```yaml
# my-values.yaml
bootstrap:
  enabled: true
  existingSecret: "service-edge-enrollment"

config:
  springProfile: "aws-secure"
  tls:
    enabled: true
    port: 9443

resources:
  limits:
    cpu: 2000m
    memory: 2Gi

ingress:
  enabled: true
  hosts:
    - host: edge.example.com
      paths:
        - path: /
          pathType: Prefix
```

```bash
helm install service-edge ./service-edge -f my-values.yaml
```

## After Enrollment

Once enrolled, the Service Edge:
- Receives mTLS client cert + HTTPS server cert (Ferentin-CA-signed, stored in certs PVC)
- Downloads the policy bundle (stored in policies PVC)
- Binds the HTTPS listener on port 9443 (binds **after** bootstrap completes — confirm with the log line below)
- Begins accepting LLM and MCP API requests

Verify enrollment:

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=service-edge

# Confirm the TLS listener bound — look for the bind log line
kubectl logs -l app.kubernetes.io/name=service-edge | grep TlsListenerService
# Expected: "TLS HTTPS listener bound on port 9443 (reason: certificates-available)"

# Test the TLS listener (port-forward 9443; --cacert points at the Ferentin
# tenant CA bundle exported from the admin console)
kubectl port-forward svc/service-edge 9443:9443
curl --cacert ferentin-ca.pem https://localhost:9443/v1/models
```

## Re-enrollment

To re-enroll an existing Service Edge:

1. Delete the existing PVCs (this removes certificates)
2. Create a new enrollment token
3. Upgrade the release with the new secret

```bash
# Delete PVCs
kubectl delete pvc -l app.kubernetes.io/instance=service-edge

# Create new secret
kubectl create secret generic service-edge-enrollment-new \
  --from-literal=ENROLLMENT_TOKEN=new-token-here

# Upgrade
helm upgrade service-edge ./service-edge \
  --set bootstrap.existingSecret=service-edge-enrollment-new
```

## Upgrade

```bash
helm upgrade service-edge ./service-edge -f my-values.yaml
```

## Uninstall

```bash
helm uninstall service-edge
```

**Note**: PVCs are not deleted automatically to preserve certificates. To remove:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=service-edge
```

## Troubleshooting

### Pod fails to start

Check the enrollment token is valid and not expired:
```bash
kubectl logs -l app.kubernetes.io/name=service-edge
```

### HTTPS not working / `Connection reset by peer` on 9443

The TLS listener binds **after** bootstrap completes — on a fresh enrollment, expect a few seconds between pod start and the listener coming up. Tail the logs:

```bash
kubectl logs -l app.kubernetes.io/name=service-edge | grep TlsListenerService
```

Look for `TLS HTTPS listener bound on port 9443 (reason: certificates-available)` (cold-start) or `(reason: application-ready)` (warm restart). If you see `TLS listener will bind once certificates are provisioned` and nothing after, bootstrap hasn't completed — check `EdgeBootstrapClientImpl` logs for the underlying error (network reachability to control plane, invalid `key-passphrase`, expired token).

### Health check failing

```bash
kubectl describe pod -l app.kubernetes.io/name=service-edge
kubectl logs -l app.kubernetes.io/name=service-edge
```
