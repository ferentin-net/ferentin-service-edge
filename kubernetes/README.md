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
  TLS_ENABLED: "true"
  TLS_PORT: "9443"
```

> Don't add `TENANT_ID`, `SITE_ID`, `EDGE_ID`, or `BOOTSTRAP_ENABLED` to the ConfigMap. Tenant / site / edge identity is derived from the JWT claims in the enrollment token (`tid`, `site_id`, `edge_id`, `edge_type`); a mismatch aborts startup. `BOOTSTRAP_ENABLED` is a kill-switch only — bootstrap auto-triggers when `ENROLLMENT_TOKEN` is present and no certs are on the cert PVC.

### 3. Storage Class

Update `pvc.yaml` with your storage class:

```yaml
spec:
  storageClassName: your-storage-class
```

## API endpoints exposed

Once enrolled, the Service Edge exposes both LLM and MCP traffic on port **9443** (HTTPS). What's active depends on the enrollment token's `capabilities` claim.

### LLM Proxy

| Endpoint | Method | Description |
|---|---|---|
| `/v1/chat/completions` | POST | OpenAI-compatible chat completions |
| `/v1/messages` | POST | Anthropic-compatible Messages API |
| `/v1/models` | GET | List available models |
| `/v1/embeddings` | POST | Embeddings API |

### MCP Gateway

| Endpoint | Method | Description |
|---|---|---|
| `/v1/mcp/{server-slug}` | POST | MCP JSON-RPC 2.0 endpoint (Streamable HTTP transport, [2025-11-25 spec](https://modelcontextprotocol.io/specification/2025-11-25)) |
| `/.well-known/oauth-protected-resource/v1/mcp` | GET | OAuth2 Protected Resource Metadata ([RFC 9728](https://www.rfc-editor.org/rfc/rfc9728)) |

`{server-slug}` is the slug of an upstream MCP server (e.g., `github`, `slack`, `stripe`) configured in the tenant's policy bundle. Each MCP request is authorized against the tenant's policy and audited per tool call.

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9443 | HTTPS | LLM + MCP API (primary). Binds **after** bootstrap completes. |
| 9080 | HTTP | Health checks and actuator only. Binds at startup; LLM/MCP endpoints are blocked here. |

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

1. mTLS client cert + HTTPS server cert (both Ferentin-CA-signed) are stored in the cert PVC.
2. Edge config (tenant ID, site ID, edge ID, edge type — all from JWT claims) is persisted.
3. The HTTPS listener binds on port 9443 — confirm with `kubectl logs -l app.kubernetes.io/name=service-edge | grep TlsListenerService` (look for `TLS HTTPS listener bound on port 9443`).
4. Policy bundle is downloaded to the policy PVC.

You can leave the enrollment-token secret in place (it's a no-op on warm restart) or delete it.

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
  service-edge=ghcr.io/ferentin-net/service-edge:0.4.1 \
  -n ferentin-service-edge
```

## Re-enrollment

If you need to re-enroll (e.g., certificates expired or revoked):

1. Obtain a new enrollment token from admin console
2. Update the secret with the new token: `kubectl create secret generic service-edge-secrets --from-literal=enrollment-token=<new> --dry-run=client -o yaml | kubectl apply -f -`
3. Add `BOOTSTRAP_FORCE=true` to the ConfigMap (or pod env) to bypass the on-disk-cert short-circuit
4. Restart: `kubectl rollout restart deployment/service-edge -n ferentin-service-edge`
5. After successful re-enrollment, remove `BOOTSTRAP_FORCE` from the ConfigMap and roll again

## Cleanup

```bash
kubectl delete -f .
kubectl delete namespace ferentin-service-edge
```
