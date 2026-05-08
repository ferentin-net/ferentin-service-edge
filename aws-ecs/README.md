# AWS ECS Deployment

Deploy Ferentin Service Edge to Amazon ECS (Fargate or EC2).

## Prerequisites

- AWS CLI configured
- ECS cluster created
- ECR access or GHCR credentials
- EFS filesystem (for persistent storage)

## Quick Start

### 1. Create EFS Filesystem

```bash
# Create EFS
aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --encrypted \
  --tags Key=Name,Value=service-edge-storage

# Note the FileSystemId (fs-xxxxxxxx)
```

### 2. Create Task Definition

Edit `task-definition.json` with your values:
- Replace `ACCOUNT_ID` with your AWS account ID
- Replace `fs-xxxxxxxx` with your EFS filesystem ID
- Update environment variables

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json
```

### 3. Create Service

```bash
aws ecs create-service \
  --cluster your-cluster \
  --service-name service-edge \
  --task-definition service-edge \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

## Task Definition

See `task-definition.json` for the complete definition.

Key configuration:

| Setting | Value |
|---------|-------|
| CPU | 512 (0.5 vCPU) |
| Memory | 1024 MB |
| User | 1000:1000 |
| ReadonlyRootFilesystem | true |

### Volumes

| Volume | Type | Path |
|--------|------|------|
| certs | EFS | `/opt/ferentin/certs` |
| policy | EFS | `/opt/ferentin/policy` |
| logs | Host | `/opt/ferentin/logs` |
| data | Host | `/opt/ferentin/data` |
| tmp | Host | `/opt/ferentin/tmp` |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9080 | HTTP | API endpoints, health checks |
| 9443 | HTTPS | TLS-encrypted API (enabled after certificate provisioning) |

The HTTPS listener on port 9443 activates automatically once server certificates are provisioned during bootstrap enrollment.

## What this exposes

Once enrolled, the Service Edge serves both LLM and MCP traffic on port **9443** (HTTPS):

| Capability | Endpoints |
|---|---|
| **LLM Proxy** | `/v1/chat/completions`, `/v1/messages`, `/v1/models`, `/v1/embeddings` — drop-in for OpenAI / Anthropic SDKs |
| **MCP Gateway** | `/v1/mcp/{server-slug}` — Streamable HTTP transport, [2025-11-25 spec](https://modelcontextprotocol.io/specification/2025-11-25); proxies to upstream MCP servers (private or SaaS) with tenant-scoped policy enforcement |

What's active is controlled by the enrollment token's `capabilities` claim, not env vars.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ENROLLMENT_TOKEN` | Yes (first run) | Enrollment token from admin console (single-use, 15-min TTL). Bootstrap auto-triggers when this is set and no certs exist on the cert volume. After enrollment it's harmless — the runner short-circuits on valid certs. Pass via Secrets Manager / SSM, not the task definition env. |
| `FERENTIN_KEY_PASSPHRASE` | Yes | Passphrase for at-rest key encryption (min 32 chars). Pass via Secrets Manager / SSM. |
| `SPRING_PROFILES_ACTIVE` | No | Spring profile (default: `aws-secure`) |
| `TLS_ENABLED` | No | Enable HTTPS listener (default: `true`) |
| `TLS_PORT` | No | HTTPS listener port (default: `9443`) |
| `BOOTSTRAP_ENABLED` | No | Kill-switch only — set to `false` to suppress bootstrap. Operators should not flip this in normal use. |
| `BOOTSTRAP_FORCE` | No | Force re-enrollment even when valid certs exist. Used during recovery scenarios. |

> **Don't add `TENANT_ID`, `SITE_ID`, or `EDGE_ID` to the task definition.** Tenant / site / edge identity is derived from the JWT claims at bootstrap; a mismatch with the token aborts startup.

## Security

### IAM Roles

1. **Execution Role**: Allows ECS to pull images and write logs
2. **Task Role**: Allows the container to access AWS services

### Secrets Management

Use AWS Secrets Manager or SSM Parameter Store:

```json
"secrets": [
  {
    "name": "ENROLLMENT_TOKEN",
    "valueFrom": "arn:aws:ssm:REGION:ACCOUNT:parameter/service-edge/enrollment-token"
  }
]
```

### Security Groups

Allow inbound:
- Port 9080 from ALB/NLB or VPC

Allow outbound:
- Port 443 to control plane
- Port 2049 to EFS

## Load Balancer

### Application Load Balancer

```bash
# Create target group
aws elbv2 create-target-group \
  --name service-edge-tg \
  --protocol HTTP \
  --port 9080 \
  --vpc-id vpc-xxx \
  --target-type ip \
  --health-check-path /actuator/health
```

### Network Load Balancer

For TCP/gRPC traffic, use NLB instead of ALB.

## Auto Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/your-cluster/service-edge \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/your-cluster/service-edge \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name service-edge-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

## Monitoring

### CloudWatch Logs

Logs are sent to `/ecs/service-edge` log group.

### Container Insights

Enable Container Insights on your cluster for detailed metrics.

### Health Checks

ECS performs health checks using the container health check:

```json
"healthCheck": {
  "command": ["CMD", "nc", "-z", "localhost", "9080"],
  "interval": 30,
  "timeout": 10,
  "retries": 3,
  "startPeriod": 60
}
```
