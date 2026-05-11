# Cloud Run Deployment

Deploy Ferentin Service Edge as a Cloud Run service.

Cloud Run terminates TLS at the Google front-end and forwards plaintext HTTP to the container. The edge runs its HTTP listener on port 9080 and skips its own HTTPS listener (TLS is handled upstream). For persistent storage of certs and the policy bundle, the recipe mounts a Filestore (NFS) volume — Cloud Run revisions are stateless, so the certs need to live outside the container instance.

> **Cloud Run is best for single-region, single-revision deployments.** For multi-region HA, prefer [`../gke/`](../gke/) — Cloud Run's volume model is designed for stateful single-revision use, not multi-replica reads-and-writes coordination.

## Prerequisites

- `gcloud` CLI authenticated and pointed at your project.
- A **Filestore instance** (Basic HDD or Enterprise) for the persistent volume. Filestore Basic minimum: 1 TiB.
- A **GCP service account** for the Cloud Run revision's runtime identity. If you'll use Vertex AI providers, this SA needs `roles/aiplatform.user`.
- A **VPC connector** (Serverless VPC Access) so Cloud Run can reach the Filestore NFS endpoint over a private IP.

## What this exposes

Once enrolled, the Service Edge serves both LLM and MCP traffic on the Cloud Run service URL (HTTPS, terminated by Cloud Run):

| Capability | Endpoints |
|---|---|
| **LLM Proxy** | `/v1/chat/completions`, `/v1/messages`, `/v1/models`, `/v1/embeddings` |
| **MCP Gateway** | `/v1/mcp/{server-slug}` — Streamable HTTP transport, [2025-11-25 spec](https://modelcontextprotocol.io/specification/2025-11-25) |

What's active is controlled by the enrollment token's `capabilities` claim.

## Quick Start

### 1. Provision Filestore + VPC connector + SA

```bash
PROJECT_ID=your-project
REGION=us-central1
NETWORK=default

# Create the Filestore instance (Basic HDD, 1 TiB minimum)
gcloud filestore instances create ferentin-edge-fs \
  --project=$PROJECT_ID \
  --location=$REGION \
  --tier=BASIC_HDD \
  --file-share=name="vol1",capacity=1TiB \
  --network=name=$NETWORK

# Note the Filestore IP for later
FILESTORE_IP=$(gcloud filestore instances describe ferentin-edge-fs \
  --location=$REGION --format='value(networks.ipAddresses[0])')
echo "Filestore IP: $FILESTORE_IP"

# Create a VPC connector so Cloud Run can reach Filestore
gcloud compute networks vpc-access connectors create ferentin-edge-conn \
  --region=$REGION \
  --network=$NETWORK \
  --range=10.8.0.0/28

# Create the runtime SA + grant Vertex AI access if needed
gcloud iam service-accounts create ferentin-edge-runtime \
  --display-name="Ferentin Edge — Cloud Run runtime identity"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:ferentin-edge-runtime@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"
```

### 2. Store secrets in Secret Manager

Cloud Run reads secrets from Secret Manager and exposes them as env vars to the container.

```bash
# Enrollment token (single-use, 15-min TTL — set just before deploy)
echo -n '<paste from admin console>' | \
  gcloud secrets create ferentin-edge-enrollment-token --data-file=-

# At-rest encryption passphrase (generate once, store securely)
openssl rand -base64 48 | tr -d '\n' | \
  gcloud secrets create ferentin-edge-key-passphrase --data-file=-

# Grant the runtime SA access
for SECRET in ferentin-edge-enrollment-token ferentin-edge-key-passphrase; do
  gcloud secrets add-iam-policy-binding $SECRET \
    --member="serviceAccount:ferentin-edge-runtime@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

### 3. Deploy

Edit `service.yaml` and replace the placeholder values:
- `PROJECT_ID` — your GCP project
- `FILESTORE_IP` — the IP from step 1
- `REGION` — your Cloud Run region

Then deploy:

```bash
gcloud run services replace service.yaml --region=$REGION

# Or, equivalent CLI form:
gcloud run deploy service-edge \
  --image=ghcr.io/ferentin-net/service-edge:0.5.5 \
  --region=$REGION \
  --port=9080 \
  --service-account=ferentin-edge-runtime@$PROJECT_ID.iam.gserviceaccount.com \
  --vpc-connector=ferentin-edge-conn \
  --vpc-egress=private-ranges-only \
  --add-volume=name=certs,type=nfs,location=$FILESTORE_IP:/vol1/certs \
  --add-volume=name=policy,type=nfs,location=$FILESTORE_IP:/vol1/policy \
  --add-volume-mount=volume=certs,mount-path=/opt/ferentin/certs \
  --add-volume-mount=volume=policy,mount-path=/opt/ferentin/policy \
  --update-secrets=ENROLLMENT_TOKEN=ferentin-edge-enrollment-token:latest \
  --update-secrets=FERENTIN_KEY_PASSPHRASE=ferentin-edge-key-passphrase:latest \
  --set-env-vars=SPRING_PROFILES_ACTIVE=aws-secure,TLS_ENABLED=false,TLS_PORT_FILTERING_ENABLED=false \
  --memory=2Gi --cpu=2 \
  --min-instances=1 --max-instances=1 \
  --no-allow-unauthenticated
```

### 4. Verify

```bash
URL=$(gcloud run services describe service-edge --region=$REGION --format='value(status.url)')

# Health check
curl "$URL/actuator/health"

# Confirm enrollment via Cloud Run logs
gcloud run services logs read service-edge --region=$REGION --limit=50 \
  | grep -E 'EdgeBootstrapClientImpl|Bootstrap completed|policy bundle'

# Test LLM API (Cloud Run terminates TLS, so the public URL is HTTPS)
curl "$URL/v1/models" -H "Authorization: Bearer $TOKEN"
```

## Why `TLS_ENABLED=false`?

Cloud Run terminates TLS at its front-end. The container only sees plaintext HTTP from the proxy, on a single port (`$PORT`, which we set to 9080). Running the edge's own HTTPS listener on top would be redundant — and Cloud Run wouldn't know to route traffic to it, since it picks one container port.

Setting `TLS_ENABLED=false` skips the [`TlsListenerService`](https://github.com/ferentin-net/ferentin-service-edge#troubleshooting) bind step entirely. `TLS_PORT_FILTERING_ENABLED=false` is also required so LLM/MCP endpoints accept traffic on the HTTP listener.

The data path is still encrypted end-to-end: Cloud Run's front-end serves a Google-managed cert to clients, and the connection from Cloud Run to your container is over Google's internal network. There is no plaintext public hop.

## Single-revision constraint

Cloud Run's NFS volume mounts are per-revision. To avoid concurrent-write conflicts on the cert volume during enrollment, set `--min-instances=1 --max-instances=1`. Once enrolled, you can safely scale to multiple instances reading the same Filestore (the certs are read-only after bootstrap), but the first revision must be alone while it bootstraps.

If you need higher throughput, use [`../gke/`](../gke/) instead — GKE handles ReadWriteMany properly via Filestore CSI with shared coordination.

## Re-enrollment

```bash
# Update the enrollment-token secret with a new value
echo -n '<new token>' | \
  gcloud secrets versions add ferentin-edge-enrollment-token --data-file=-

# Force re-enrollment by adding BOOTSTRAP_FORCE=true and rolling the revision
gcloud run services update service-edge --region=$REGION \
  --set-env-vars=BOOTSTRAP_FORCE=true

# After successful re-enrollment, remove BOOTSTRAP_FORCE
gcloud run services update service-edge --region=$REGION \
  --remove-env-vars=BOOTSTRAP_FORCE
```

## Custom domain

Use a Cloud Run domain mapping or front it with an HTTPS Load Balancer + Serverless NEG:

```bash
gcloud run domain-mappings create \
  --service=service-edge \
  --domain=edge.example.com \
  --region=$REGION
```

Configure DNS as instructed by the command output.

## See also

- [`../gke/`](../gke/) — Recommended for production HA on GCP
- [`../gce/`](../gce/) — VM-based deployment if you can't use Cloud Run or GKE
- Main [README](../README.md) — env-var tables, tag granularities, troubleshooting
