# Service Edge Helm Chart

Helm chart for deploying Ferentin Service Edge to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Installation

```bash
# Add the repository (when published)
# helm repo add ferentin https://charts.ferentin.com

# Install with default values
helm install service-edge ./service-edge \
  --set config.controlPlaneUrl=https://cp.example.com \
  --set config.edgeId=edge-001 \
  --set config.tenantId=tenant-123

# Install with custom values file
helm install service-edge ./service-edge -f my-values.yaml
```

## Configuration

### Required Values

| Parameter | Description |
|-----------|-------------|
| `config.controlPlaneUrl` | Control plane URL |
| `config.edgeId` | Unique edge node ID |
| `config.tenantId` | Tenant ID |

### Optional Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `config.siteId` | `""` | Site ID for multi-site |
| `config.springProfile` | `production` | Spring profile |
| `config.enableVirtualThreads` | `false` | Enable virtual threads |
| `config.javaOpts` | `""` | Custom JVM options |
| `config.caBundle` | `""` | Custom CA bundle (PEM) |

### Image

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `ghcr.io/ferentin-net/service-edge` | Image repository |
| `image.tag` | `latest` | Image tag |
| `image.pullPolicy` | `Always` | Pull policy |

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
| `service.port` | `9080` | Service port |

### Ingress

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.className` | `""` | Ingress class |
| `ingress.hosts` | `[]` | Ingress hosts |

## Examples

### Basic Installation

```bash
helm install service-edge ./service-edge \
  --set config.controlPlaneUrl=https://cp.example.com \
  --set config.edgeId=edge-001 \
  --set config.tenantId=tenant-123
```

### With Custom Resources

```bash
helm install service-edge ./service-edge \
  --set config.controlPlaneUrl=https://cp.example.com \
  --set config.edgeId=edge-001 \
  --set config.tenantId=tenant-123 \
  --set resources.limits.memory=2Gi \
  --set resources.limits.cpu=2000m
```

### With Ingress

```bash
helm install service-edge ./service-edge \
  --set config.controlPlaneUrl=https://cp.example.com \
  --set config.edgeId=edge-001 \
  --set config.tenantId=tenant-123 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=edge.example.com \
  --set ingress.hosts[0].paths[0].path=/
```

### Using values.yaml

```yaml
# my-values.yaml
config:
  controlPlaneUrl: "https://cp.example.com"
  edgeId: "edge-001"
  tenantId: "tenant-123"
  springProfile: "production"

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

## Upgrade

```bash
helm upgrade service-edge ./service-edge -f my-values.yaml
```

## Uninstall

```bash
helm uninstall service-edge
```

**Note**: PVCs are not deleted automatically. To remove:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=service-edge
```
