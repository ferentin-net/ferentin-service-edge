# GKE Deployment

Deploy Ferentin Service Edge to Google Kubernetes Engine (GKE Standard or Autopilot).

The manifests in this directory extend the [generic Kubernetes recipe](../kubernetes/) with GCP-specific glue:

- **Workload Identity** binds the pod's KSA to a GCP service account so Vertex AI calls (and other GCP services) resolve their credentials at runtime — no stored cloud secrets.
- **Filestore CSI** for the certs PVC so persisted mTLS material survives node restarts and rolling updates.
- **`BackendConfig`** for the GKE L7 ingress with health checks pointed at the HTTP listener (port 9080).
- **`ManagedCertificate`** for a Google-managed public TLS cert on the public hostname.

## Prerequisites

- GKE cluster with **Workload Identity** enabled (Autopilot has it on by default).
- `kubectl` configured against the cluster.
- A GCP project with the Vertex AI API enabled (only required if you'll use Vertex providers).
- The Filestore CSI driver enabled on the cluster (Standard clusters: enable in `Features → Storage`; Autopilot: on by default).

## What this exposes

Once enrolled, the Service Edge serves both LLM and MCP traffic on port **9443** (HTTPS):

| Capability | Endpoints |
|---|---|
| **LLM Proxy** | `/v1/chat/completions`, `/v1/messages`, `/v1/models`, `/v1/embeddings` |
| **MCP Gateway** | `/v1/mcp/{server-slug}` — Streamable HTTP transport, [2025-11-25 spec](https://modelcontextprotocol.io/specification/2025-11-25) |

What's active is controlled by the enrollment token's `capabilities` claim.

## Quick Start

### 1. Bind a GCP service account via Workload Identity

The edge needs a GCP SA bound to its KSA so Vertex AI provider calls resolve runtime credentials from the GKE metadata server.

```bash
PROJECT_ID=your-project
GSA_NAME=ferentin-edge-vertex
NAMESPACE=ferentin
KSA_NAME=ferentin-edge

# 1. Create the GCP SA
gcloud iam service-accounts create $GSA_NAME \
  --project=$PROJECT_ID \
  --display-name="Ferentin Edge — Vertex AI runtime identity"

# 2. Grant Vertex AI access (or a more specific role)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# 3. Bind the K8s SA to the GCP SA via Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]"
```

### 2. Create namespace and secrets

```bash
kubectl create namespace ferentin

# Enrollment token (single-use, 15-min TTL) and at-rest passphrase
kubectl create secret generic service-edge-secrets \
  --namespace=ferentin \
  --from-literal=enrollment-token='<paste from admin console>' \
  --from-literal=key-passphrase="$(openssl rand -base64 48)"
```

### 3. Deploy

Edit `serviceaccount.yaml` and replace `GSA_NAME@PROJECT_ID.iam.gserviceaccount.com` with your bound GCP SA, then:

```bash
kubectl apply -f serviceaccount.yaml
kubectl apply -f configmap.yaml
kubectl apply -f filestore-pvc.yaml      # Persistent volume for certs + policy (Filestore CSI)
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f backendconfig.yaml      # GKE L7 health check on port 9080
# Optional: external HTTPS via GKE Ingress with managed cert
kubectl apply -f managedcertificate.yaml
kubectl apply -f ingress.yaml
```

### 4. Verify

```bash
# Pod ready?
kubectl get pods -n ferentin -l app.kubernetes.io/name=service-edge

# Workload Identity bound? (KSA should have the iam.gke.io/gcp-service-account annotation)
kubectl describe sa ferentin-edge -n ferentin

# TLS listener bound?
kubectl logs -n ferentin -l app.kubernetes.io/name=service-edge | grep TlsListenerService
# Expected: "TLS HTTPS listener bound on port 9443 (reason: certificates-available)"

# If using Ingress: check the LB IP and cert provisioning status
kubectl get ingress -n ferentin
kubectl get managedcertificate -n ferentin
```

The managed cert can take 15-60 minutes to provision after DNS resolves to the LB IP.

## Notes on Workload Identity for Vertex AI

The platform's Vertex provider supports `auth_type=attached_service_account` (ADC mode), which uses the GKE metadata server to mint tokens for the bound GCP SA. No service-account JSON, no WIF config — the cloud itself vouches for the edge.

For cross-project Vertex (edge in project A calls Vertex in project B):

```bash
gcloud projects add-iam-policy-binding $PROJECT_B \
  --member="serviceAccount:$GSA_NAME@$PROJECT_A.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"
```

In the admin console, configure the Vertex provider instance with project B's ID. The edge's runtime identity (project A) authenticates; the Vertex API call hits project B.

For chained-SA impersonation (runtime SA impersonates a target SA), set `impersonate_sa_email` in the provider instance config. The runtime SA must hold `roles/iam.serviceAccountTokenCreator` on the target.

## Storage classes

| Storage class | Backing | When to use |
|---|---|---|
| `standard-rwo` | Persistent Disk Standard | Single-replica, dev/test |
| `premium-rwo` | Persistent Disk Balanced | Single-replica, default for production |
| `enterprise-rwx` | Filestore CSI | Multi-replica, ReadWriteMany — required if you scale `replicas > 1` since the certs PVC is shared |

The provided `filestore-pvc.yaml` uses `enterprise-rwx` (Filestore CSI) because the typical production deployment scales to multiple replicas behind a service. For a single-replica deployment, switch to `premium-rwo` and `accessModes: [ReadWriteOnce]`.

## Re-enrollment

```bash
# Refresh the enrollment-token secret with a new token
kubectl create secret generic service-edge-secrets \
  --namespace=ferentin \
  --from-literal=enrollment-token='<new token>' \
  --from-literal=key-passphrase=$(kubectl get secret service-edge-secrets -n ferentin -o jsonpath='{.data.key-passphrase}' | base64 -d) \
  --dry-run=client -o yaml | kubectl apply -f -

# Add BOOTSTRAP_FORCE=true to the ConfigMap to bypass the on-disk-cert short-circuit
kubectl patch configmap service-edge-config -n ferentin \
  --patch '{"data":{"BOOTSTRAP_FORCE":"true"}}'

# Roll the deployment
kubectl rollout restart deployment/service-edge -n ferentin

# After successful re-enrollment, remove BOOTSTRAP_FORCE
kubectl patch configmap service-edge-config -n ferentin \
  --type=json --patch='[{"op":"remove","path":"/data/BOOTSTRAP_FORCE"}]'
kubectl rollout restart deployment/service-edge -n ferentin
```

## See also

- [`../kubernetes/`](../kubernetes/) — generic Kubernetes recipe (the GKE manifests here extend it)
- [`../helm/service-edge/`](../helm/service-edge/) — Helm chart (works on GKE; pass `serviceAccount.annotations` for Workload Identity)
- Main [README](../README.md) — env-var tables, tag granularities, troubleshooting
