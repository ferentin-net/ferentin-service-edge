# Kubernetes Deployment

Deploy Ferentin Service Edge to Kubernetes.

## Prerequisites

1. **Obtain an enrollment token** from the Ferentin admin console
2. Kubernetes cluster with kubectl configured
3. Storage class for persistent volumes

## Quick Start

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create secrets with enrollment token
kubectl create secret generic service-edge-secrets \
  --from-literal=enrollment-token=your-enrollment-token-here \
  -n ferentin-service-edge

# Create config
kubectl apply -f configmap.yaml

# Create persistent volumes
kubectl apply -f pvc.yaml

# Deploy
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Configuration

### 1. Edit Secrets

Create the secret with your enrollment token:

```bash
kubectl create secret generic service-edge-secrets \
  --from-literal=enrollment-token=your-enrollment-token-here \
  -n ferentin-service-edge
```

### 2. Edit ConfigMap (Optional)

The `configmap.yaml` contains default settings:

```yaml
data:
  SPRING_PROFILES_ACTIVE: "aws-secure"
  BOOTSTRAP_ENABLED: "true"
  TLS_ENABLED: "true"
  TLS_PORT: "9443"
```

### 3. Storage Class

Update `pvc.yaml` with your storage class:

```yaml
spec:
  storageClassName: your-storage-class
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9080 | HTTP | API endpoints, health checks |
| 9443 | HTTPS | TLS-encrypted API (enabled after certificate provisioning) |

## Verify Deployment

```bash
# Check pods
kubectl get pods -n ferentin-service-edge

# Check logs
kubectl logs -f deployment/service-edge -n ferentin-service-edge

# Check health
kubectl exec -n ferentin-service-edge deployment/service-edge -- nc -z localhost 9080

# Test API
kubectl port-forward svc/service-edge 9080:9080 -n ferentin-service-edge
curl http://localhost:9080/actuator/health
```

## Expose Service

### NodePort

```yaml
spec:
  type: NodePort
  ports:
    - name: http
      port: 9080
      nodePort: 30080
    - name: https
      port: 9443
      nodePort: 30443
```

### LoadBalancer

```yaml
spec:
  type: LoadBalancer
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-edge
  namespace: ferentin-service-edge
spec:
  rules:
    - host: edge.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-edge
                port:
                  number: 9080
```

## After Enrollment

Once enrolled successfully:

1. The edge node receives its identity (EDGE_ID, TENANT_ID, SITE_ID)
2. mTLS certificates are stored in the persistent volume
3. The HTTPS listener starts on port 9443
4. Policy bundles are downloaded

You can optionally:
- Remove the enrollment token from secrets
- Set `BOOTSTRAP_ENABLED=false` in the ConfigMap

## Scaling

```bash
# Scale replicas
kubectl scale deployment/service-edge --replicas=3 -n ferentin-service-edge
```

**Note**: When scaling, ensure PVCs support `ReadWriteMany` or use a shared storage solution.

## Upgrade

```bash
# Update image tag in deployment.yaml, then:
kubectl apply -f deployment.yaml

# Or use set image:
kubectl set image deployment/service-edge \
  service-edge=ghcr.io/ferentin-net/service-edge:1.0.1 \
  -n ferentin-service-edge
```

## Re-enrollment

If you need to re-enroll (e.g., certificates expired):

1. Obtain a new enrollment token from admin console
2. Update the secret with the new token
3. Set `BOOTSTRAP_ENABLED=true` in ConfigMap
4. Restart: `kubectl rollout restart deployment/service-edge -n ferentin-service-edge`

## Cleanup

```bash
kubectl delete -f .
kubectl delete namespace ferentin-service-edge
```
