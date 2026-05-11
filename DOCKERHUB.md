# Ferentin Service Edge

**A hardened, signed, self-hosted [LLM router](https://ferentin.com/glossary) and [MCP gateway](https://ferentin.com/glossary) container.** Drop it in front of OpenAI, Anthropic, AWS Bedrock, Google Vertex, xAI, Mistral, vLLM, Ollama — or any Model Context Protocol server — and enforce policy, audit every call, and keep customer data inside your perimeter.

Published by **[Ferentin](https://ferentin.com)** — the enterprise AI control plane.

[![Docker Pulls](https://img.shields.io/docker/pulls/ferentin/service-edge?logo=docker&logoColor=white)](https://hub.docker.com/r/ferentin/service-edge)
[![Image Size](https://img.shields.io/docker/image-size/ferentin/service-edge/latest?logo=docker&logoColor=white)](https://hub.docker.com/r/ferentin/service-edge/tags)
[![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-blue?logo=linux&logoColor=white)](https://hub.docker.com/r/ferentin/service-edge/tags)
[![Signed with Cosign](https://img.shields.io/badge/signed-cosign%20keyless-success?logo=sigstore&logoColor=white)](#-supply-chain-security--image-signing)
[![SBOM](https://img.shields.io/badge/SBOM-attached-success?logo=securityscorecard&logoColor=white)](#-supply-chain-security--image-signing)
[![Java](https://img.shields.io/badge/Java-25%20LTS-007396?logo=openjdk&logoColor=white)](https://ferentin.com/blog)
[![Website](https://img.shields.io/badge/website-ferentin.com-0066cc)](https://ferentin.com)

---

## 🚀 Quick start

```bash
docker pull ferentin/service-edge:latest
```

```bash
docker volume create service-edge-certs
docker volume create service-edge-policy

docker run -d \
  --name service-edge \
  --read-only \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  -v service-edge-certs:/opt/ferentin/certs:rw \
  -v service-edge-policy:/opt/ferentin/policy:rw \
  --tmpfs /opt/ferentin/logs:rw,uid=1000,gid=1000,noexec,nosuid,size=100m \
  --tmpfs /opt/ferentin/data:rw,uid=1000,gid=1000,noexec,nosuid,size=50m \
  --tmpfs /opt/ferentin/tmp:rw,uid=1000,gid=1000,noexec,nosuid,size=100m \
  -p 9443:9443 \
  -e SPRING_PROFILES_ACTIVE=aws-secure \
  -e ENROLLMENT_TOKEN=<paste-from-admin-console> \
  ferentin/service-edge:latest
```

Get an enrollment token from the **[Ferentin admin console](https://ferentin.com/get-started)**, point your OpenAI-compatible SDK at `https://localhost:9443/v1`, and you're done.

📖 Full deployment recipes — [Docker Compose](https://github.com/ferentin-net/ferentin-service-edge/blob/main/docker-compose/README.md), [Kubernetes](https://github.com/ferentin-net/ferentin-service-edge/blob/main/kubernetes/README.md), [Helm](https://github.com/ferentin-net/ferentin-service-edge/blob/main/helm/service-edge/README.md), [AWS ECS](https://github.com/ferentin-net/ferentin-service-edge/blob/main/aws-ecs/README.md), [GCP Cloud Run / GKE / GCE](https://github.com/ferentin-net/ferentin-service-edge/blob/main/cloud-run/README.md), [Fly.io](https://github.com/ferentin-net/ferentin-service-edge/blob/main/fly.io/README.md), [Render](https://github.com/ferentin-net/ferentin-service-edge/blob/main/render/README.md), [Railway](https://github.com/ferentin-net/ferentin-service-edge/blob/main/railway/README.md) — are in the [GitHub repository](https://github.com/ferentin-net/ferentin-service-edge).

---

## What this image is

The Ferentin **Service Edge** is the data-plane half of [the Ferentin AI control plane](https://ferentin.com/platform). It runs at your edge — inside your VPC, on-prem, in your Kubernetes cluster, anywhere your AI traffic originates — and acts as:

| Role | What it does |
|------|--------------|
| **OpenAI-compatible API proxy** | Speaks `/v1/chat/completions`, `/v1/embeddings`, `/v1/models` — point any OpenAI SDK at it |
| **Anthropic API proxy** | Speaks `/v1/messages` for Claude SDK compatibility |
| **MCP gateway** | Brokers [Model Context Protocol](https://ferentin.com/glossary) calls to upstream MCP servers, with per-user OAuth or per-tenant API-key auth |
| **Policy enforcement point** | Evaluates DLP, model-allowlist, redaction, and rate-limit policies on every prompt/completion |
| **Audit & telemetry tap** | Emits every LLM and MCP event over **gRPC + mTLS** to the Ferentin control plane — no log scraping, no agent sidecars |
| **Multi-provider router** | Routes by model, tenant, or policy — across OpenAI, Anthropic, [AWS Bedrock](https://ferentin.com/blog), Google Vertex, Google AI Studio, Azure OpenAI, xAI Grok, Mistral, vLLM, Ollama |

Your prompts, completions, embeddings, and tool calls **never leave your network**. Only signed, structured telemetry does — and you control which fields are exported.

➡️ Learn more on the [Ferentin platform overview](https://ferentin.com/platform) and the [security architecture](https://ferentin.com/security).

---

## Why this exists

Most teams hit the same wall around the second or third LLM integration:

- **Shadow AI** — every team picks their own provider, no central audit trail
- **Compliance black holes** — SOC2, HIPAA, GDPR need provable data residency and access controls on AI traffic
- **Vendor lock-in** — switching from OpenAI to Anthropic means rewriting clients
- **No DLP** — prompts leak PII, customer data, and source code straight to third-party LLMs
- **MCP sprawl** — every assistant wants its own MCP server tokens, with no consent flow or session controls

The Service Edge solves all of that with one container in your network. See the [LLM router comparison](https://ferentin.com/compare) for how this approach compares to API gateways, LiteLLM, and other tools.

---

## ✨ Image features

- ✅ **Java 25 LTS** on a hardened Ubuntu 24.04 (Noble) base
- ✅ **Custom `jlink` JRE** — 25 modules instead of 69 (~81 % smaller, smaller attack surface)
- ✅ **AOT cache (JEP 483)** — pre-loaded classes + method profiles for **40–60 % faster startup**
- ✅ **Multi-arch** — `linux/amd64` and `linux/arm64` (Graviton-native)
- ✅ **Non-root** (UID/GID `1000:1000`)
- ✅ **Read-only root filesystem** compatible
- ✅ **No package manager** at runtime — `apt` removed after install
- ✅ **No `curl` / `wget`** in the runtime image
- ✅ **setuid/setgid bits stripped** from every binary
- ✅ **JMX disabled** — `jdk.management.agent` excluded from the jlink JRE
- ✅ Cap-drop ALL + `no-new-privileges` friendly
- ✅ End-to-end TLS 1.3 (port `9443`) — no plaintext LLM traffic
- ✅ Multi-tenant — single image serves many tenants via policy bundles

The [hardening notes](https://github.com/ferentin-net/ferentin-service-edge/blob/main/SECURITY.md) describe each control and how it maps to CIS Docker Benchmark and STIG.

---

## 🔒 Supply chain security & image signing

Every published image is **signed with [Sigstore Cosign](https://docs.sigstore.dev/cosign/overview/)** and ships with an attached **SBOM** (SPDX format).

Customers in regulated environments who need to wire image-signature verification into their admission controller, CI pipeline, or compliance evidence should contact [security@ferentin.com](mailto:security@ferentin.com) — we'll provide the exact verification recipe for your environment.

Pin to a digest in production:

```bash
docker pull ferentin/service-edge@sha256:<digest>
```

### Inspect the SBOM

```bash
docker buildx imagetools inspect \
  --format '{{ json .SBOM }}' \
  ferentin/service-edge:latest
```

Or, with Cosign:

```bash
cosign download sbom ferentin/service-edge:latest > sbom.spdx.json
```

### Reproducible builds

- **Base images pinned by digest** in the Dockerfile (not `:latest`)
- **Gradle distribution pinned by SHA-256**
- **JAR built on a native runner** then copied into the image
- **OCI labels** record `org.opencontainers.image.source`, `vendor`, `version`, and security posture flags (`com.ferentin.security.non-root=true`, `read-only-rootfs=true`)

Full details in [`SECURITY.md`](https://github.com/ferentin-net/ferentin-service-edge/blob/main/SECURITY.md) and the [Ferentin security page](https://ferentin.com/security).

---

## 🏷️ Tags & versioning

| Tag | Meaning |
|-----|---------|
| `latest` | Most recent stable release |
| `X.Y.Z` (e.g., `0.5.2`) | Immutable, signed semver release |
| `X.Y` | Latest patch in a minor line |
| `X` | Latest minor in a major line |
| `sha-<short>` | Git commit reference (forensic use) |
| `*-rc*`, `*-alpha*`, `*-beta*` | Pre-release — not tagged `latest` |

For production, **always pin to either `X.Y.Z` or a `sha256:` digest** — never `latest`. Browse all tags on the [Tags tab](https://hub.docker.com/r/ferentin/service-edge/tags).

Releases are also mirrored to:

- **GitHub Container Registry** — `ghcr.io/ferentin-net/service-edge`
- **Amazon ECR Public** — for customers running in AWS

---

## 📐 Ports & volumes

| Port | Purpose | Expose externally? |
|------|---------|-------------------|
| `9443` | TLS-terminated LLM / MCP API (primary) | **Yes** — clients connect here |
| `9080` | Health & actuator endpoints | No — internal only |

| Volume | Type | Purpose |
|--------|------|---------|
| `/opt/ferentin/certs` | **Persistent** | mTLS certificates from edge enrollment — must survive restarts |
| `/opt/ferentin/policy` | Persistent or tmpfs | Hot-reloadable policy bundle |
| `/opt/ferentin/logs` | tmpfs | Application logs |
| `/opt/ferentin/data` | tmpfs | Runtime data |
| `/opt/ferentin/tmp` | tmpfs | Java temp files |

---

## ⚙️ Configuration (essentials)

| Variable | Required | Description |
|----------|----------|-------------|
| `ENROLLMENT_TOKEN` | First run | JWT issued by your Ferentin admin console |
| `SPRING_PROFILES_ACTIVE` | Yes | `aws-secure` (production) or `nginx` (dev) |
| `FERENTIN_KEY_PASSPHRASE` | Yes | Passphrase that decrypts the edge's at-rest cred cache |
| `EDGE_CA_BUNDLE` | Optional | Custom CA bundle (PEM) for corporate proxies |
| `JAVA_OPTS` | Optional | Extra JVM flags (merged with sensible defaults) |

After first enrollment, `EDGE_ID`, `TENANT_ID`, and `SITE_ID` are persisted in `/opt/ferentin/certs/edge-config.properties`.

Full reference: [environment variables](https://github.com/ferentin-net/ferentin-service-edge#environment-variables) · [TLS configuration](https://github.com/ferentin-net/ferentin-service-edge/blob/main/TLS.md).

---

## 🩺 Health checks

```bash
curl https://localhost:9443/actuator/health
curl https://localhost:9443/actuator/health/liveness
curl https://localhost:9443/actuator/health/readiness
```

The Dockerfile ships a built-in `HEALTHCHECK` that probes TCP `9080`. Container orchestrators should use the `/actuator/health/*` endpoints for finer signals.

---

## 🔗 Resources

### Documentation

- 🌐 **[ferentin.com](https://ferentin.com)** — product homepage
- 🧭 **[Platform overview](https://ferentin.com/platform)** — how Service Edge fits with the control plane
- 🔐 **[Security & compliance](https://ferentin.com/security)** — controls, certifications, threat model
- 🚀 **[Get started](https://ferentin.com/get-started)** — sign up, get an enrollment token
- 📚 **[Guides](https://ferentin.com/guides)** — deployment & integration tutorials
- 🔍 **[LLM info hub](https://ferentin.com/llm-info)** — model cards, pricing, capabilities
- 📖 **[Glossary](https://ferentin.com/glossary)** — LLM router, MCP, policy enforcement defined
- 🆚 **[Comparisons](https://ferentin.com/compare)** — Ferentin vs LiteLLM, vs API gateways, vs DIY proxies
- ✍️ **[Engineering blog](https://ferentin.com/blog)**
- 📣 **[Book a demo](https://ferentin.com/book-a-demo)**

### Source & releases

- 📦 **[GitHub: deployment recipes](https://github.com/ferentin-net/ferentin-service-edge)** — Docker Compose, K8s, Helm, ECS, Cloud Run, Fly, Render, Railway
- 🛡️ **[SECURITY.md](https://github.com/ferentin-net/ferentin-service-edge/blob/main/SECURITY.md)** — vulnerability disclosure & hardening notes
- 📜 **[Release notes](https://github.com/ferentin-net/ferentin-service-edge/releases)**

### Compliance & policy

- 🔒 **[Privacy policy](https://ferentin.com/privacy-policy)**
- 📄 **[Terms of service](https://ferentin.com/terms-of-service)**
- ✅ **[Acceptable use policy](https://ferentin.com/acceptable-use-policy)**
- 🤝 **[Sub-processors](https://ferentin.com/sub-processors)**

### Support

- 💬 **[Support](https://ferentin.com/support)**
- 🐛 **[Open an issue](https://github.com/ferentin-net/ferentin-service-edge/issues)**

---

## License

Proprietary. Commercial use of the Service Edge container requires an active Ferentin subscription. See **[ferentin.com/terms-of-service](https://ferentin.com/terms-of-service)** or contact **sales@ferentin.com**.

---

<sub>**Keywords:** LLM router · AI gateway · OpenAI-compatible proxy · Anthropic Claude proxy · MCP gateway · Model Context Protocol · self-hosted AI proxy · enterprise AI control plane · LLM policy enforcement · LLM DLP · AI audit logging · multi-provider LLM router · zero-trust AI · mTLS · cosign-signed container · SBOM · Java 25 · Spring Boot · Sigstore · supply-chain security · GDPR · SOC2 · HIPAA · data sovereignty · AI governance · Bedrock proxy · Vertex AI · xAI Grok · Mistral · vLLM · Ollama. Maintained by [Ferentin](https://ferentin.com).</sub>
