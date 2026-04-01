# TLS and Load Balancing Guide

How to configure end-to-end encryption and load balance Service Edge instances — whether deployed on-premise, in the cloud, or on a PaaS platform.

## Certificate Architecture

During bootstrap enrollment, each Service Edge instance receives **two certificate pairs**:

| Certificate | Files | Purpose |
|-------------|-------|---------|
| **Client cert** | `client.crt` / `client.key` | Authenticates the edge to the Ferentin control plane (mTLS) |
| **Server cert** | `server.crt` / `server.key` | Encrypts traffic on the HTTPS listener (port 9443) |

- **Client certs** renew automatically at 80% of lifetime. If the cert expires, the edge shuts down.
- **Server certs** provide encryption only. They are signed by the Ferentin Edge CA (not a public CA). An expired server cert still encrypts traffic — only verification fails, not encryption.
- **Never share certificates** between edge instances. Each instance has its own identity.

## Load Balancing Multiple Edges

For high availability, deploy multiple edge instances behind a reverse proxy at each site. The load balancer terminates the public TLS certificate and re-encrypts to the edges.

```
      Clients (SDKs, Apps, AI Agents)
                 │
                 │ HTTPS
                 ▼
          ┌──────────────┐
          │ Load Balancer │
          └──┬────────┬──┘
             │        │
       HTTPS │        │ HTTPS   ← end-to-end encrypted
             ▼        ▼
         Edge 1    Edge 2
          :9443     :9443
```

**Key points**:
- Each edge enrolls separately with its own enrollment token
- Sticky sessions are not required — edges are stateless
- Health checks should target port **9080** (`/actuator/health`), not the TLS port
- Skip backend cert verification (the edge's server cert is signed by the Ferentin Edge CA, not a public CA) — the connection is still encrypted

## Cloud and PaaS Deployments

### Managed Load Balancers (AWS, GCP, Azure)

Cloud providers offer managed load balancers that support backend TLS natively. No special edge configuration is needed — just point the load balancer at port 9443 with HTTPS.

| Provider | Load Balancer | Backend TLS | Configuration |
|----------|--------------|-------------|---------------|
| **AWS** | Application Load Balancer (ALB) | HTTPS target group on port 9443 | ALB does not verify backend certs by default |
| **GCP** | Cloud Load Balancing | HTTPS backend service on port 9443 | Set health check to HTTP:9080 |
| **Azure** | Application Gateway | HTTPS backend pool on port 9443 | Upload Edge CA as trusted root, or use "well known CA" = No |

For all providers:
- **Target/backend port**: 9443 (HTTPS)
- **Health check port**: 9080 (HTTP)
- **Health check path**: `/actuator/health`
- **Backend cert verification**: Not required (Edge CA is not a public CA). The connection is still encrypted.

### PaaS Platforms (Fly.io, Railway, Render)

PaaS platforms handle TLS termination automatically — they provision a public certificate for your domain and route traffic to your container.

| Platform | How it works |
|----------|-------------|
| **Fly.io** | Terminates TLS at the edge. Set `internal_port = 9443` in `fly.toml`. Fly connects to your container over the private network — enable `TLS_ENABLED=true` for encryption on this leg. |
| **Railway** | Terminates TLS automatically. Expose port 9443 and Railway routes HTTPS traffic to it. |
| **Render** | Terminates TLS automatically. Configure the service with port 9443. |

On PaaS, you typically run a single edge instance per service. For high availability, deploy multiple services and use the platform's built-in load balancing or DNS-based failover.

## Self-Managed Reverse Proxies

### Nginx

```nginx
upstream service-edge {
    server edge-1:9443 max_fails=3 fail_timeout=30s;
    server edge-2:9443 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl;
    server_name ai-gateway.example.com;

    ssl_certificate     /etc/nginx/certs/public.crt;
    ssl_certificate_key /etc/nginx/certs/public.key;

    location / {
        proxy_pass https://service-edge;
        proxy_ssl_verify off;
        proxy_ssl_protocols TLSv1.3;
        proxy_ssl_session_reuse on;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Required for SSE streaming (MCP, chat completions)
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
    }
}
```

### HAProxy

```
frontend ai-gateway
    bind *:443 ssl crt /etc/haproxy/certs/public.pem
    default_backend edges

backend edges
    balance roundrobin
    option httpchk GET /actuator/health
    http-check expect status 200
    server edge-1 edge-1:9443 ssl verify none check port 9080
    server edge-2 edge-2:9443 ssl verify none check port 9080
```

### Caddy

```
ai-gateway.example.com {
    reverse_proxy edge-1:9443 edge-2:9443 {
        lb_policy round_robin
        transport http {
            tls
            tls_insecure_skip_verify
        }
        health_uri /actuator/health
        health_port 9080
        health_interval 30s
    }
}
```

### Envoy

Use an upstream TLS context with `trust_chain_verification: ACCEPT_UNTRUSTED` on the cluster pointing to port 9443, and HTTP health checks on port 9080. See the [Envoy TLS upstream documentation](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/security/ssl) for details.

## TLS Passthrough (Alternative)

If you don't need the load balancer to inspect HTTP headers, you can pass TLS connections through directly (L4). The edge's own server certificate is presented to clients.

**Nginx stream**:
```nginx
stream {
    upstream service-edge {
        server edge-1:9443;
        server edge-2:9443;
    }
    server {
        listen 9443;
        proxy_pass service-edge;
    }
}
```

**Tradeoff**: No path-based routing, no header injection, TCP-only health checks.
