# Kubernetes Deployment

Deploy Ferentin Service Edge to Kubernetes.

## Quick Start

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create secrets (edit first!)
kubectl apply -f secret.yaml

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

Update `secret.yaml` with your edge credentials:

```yaml
stringData:
  edge-id: "your-edge-id"
  tenant-id: "your-tenant-id"
```

### 2. Edit ConfigMap

Update `configmap.yaml` with your control plane URL:

```yaml
data:
  EDGE_CONTROL_PLANE_URL: "https://your-cp.example.com"
```

### 3. Storage Class

Update `pvc.yaml` with your storage class:

```yaml
spec:
  storageClassName: your-storage-class
```

## Verify Deployment

```bash
# Check pods
kubectl get pods -n ferentin-service-edge

# Check logs
kubectl logs -f deployment/service-edge -n ferentin-service-edge

# Check health
kubectl exec -n ferentin-service-edge deployment/service-edge -- nc -z localhost 9080
```

## Expose Service

### NodePort

```yaml
spec:
  type: NodePort
  ports:
    - port: 9080
      nodePort: 30080
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

## Cleanup

```bash
kubectl delete -f .
kubectl delete namespace ferentin-service-edge
```
