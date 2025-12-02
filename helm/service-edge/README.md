# Service Edge Helm Chart

Helm chart for deploying Ferentin Service Edge to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Enrollment token from [Ferentin Admin Console](https://console.ferentin.net)

## Quick Start

### 1. Get an Enrollment Token

1. Log into the [Ferentin Admin Console](https://console.ferentin.net)
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

## Configuration

### Bootstrap Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `bootstrap.enabled` | `true` | Enable bootstrap enrollment |
| `bootstrap.existingSecret` | `""` | Name of secret containing ENROLLMENT_TOKEN |
| `config.springProfile` | `aws-secure` | Spring profile |

### TLS Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `config.tls.enabled` | `true` | Enable HTTPS listener on port 9443 |
| `config.tls.port` | `9443` | HTTPS listener port |

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
| `config.enableVirtualThreads` | `false` | Enable Java 21 virtual threads |
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
- Receives mTLS certificates (stored in certs PVC)
- Downloads policy bundles (stored in policies PVC)
- Activates HTTPS listener on port 9443
- Begins accepting LLM API requests

Verify enrollment:

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=service-edge

# Check logs
kubectl logs -l app.kubernetes.io/name=service-edge

# Test health endpoint
kubectl port-forward svc/service-edge 9080:9080
curl http://localhost:9080/actuator/health

# Test LLM API (after enrollment completes)
curl http://localhost:9080/v1/models
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

### HTTPS not working

The TLS listener requires server certificates in the certs PVC. These are automatically provisioned during bootstrap enrollment. Check enrollment completed successfully.

### Health check failing

```bash
kubectl describe pod -l app.kubernetes.io/name=service-edge
kubectl logs -l app.kubernetes.io/name=service-edge
```
