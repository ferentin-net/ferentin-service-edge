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

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SPRING_PROFILES_ACTIVE` | No | Spring profile (default: `aws-secure`) |
| `BOOTSTRAP_ENABLED` | Yes | Set to `true` for first-time enrollment |
| `ENROLLMENT_TOKEN` | Yes | Enrollment token from admin console |

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
