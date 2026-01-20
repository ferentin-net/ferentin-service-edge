# Security Policy

## Repository Classification

**Public Repository - Intentionally Public**

This repository is intentionally public as it contains deployment documentation and configuration templates for Ferentin Service Edge. It is designed to help customers deploy the Service Edge in their own infrastructure.

### What This Repository Contains

- Deployment guides and templates (Docker Compose, Kubernetes, Helm, AWS ECS, Fly.io, Railway, Render)
- Configuration examples with placeholder values
- Documentation for self-hosted deployments

### What This Repository Does NOT Contain

- Source code for the Service Edge application
- API keys, secrets, or credentials
- Internal configuration or infrastructure details
- Customer data or personally identifiable information (PII)

## Security Controls

### Secrets Management

All sensitive data is excluded from this repository:

- `.gitignore` prevents committing `.env` files, secrets, certificates, and keys
- All configuration templates use placeholder values (e.g., `your-enrollment-token-here`)
- Actual secrets are provisioned at runtime via:
  - AWS Secrets Manager / SSM Parameter Store
  - Kubernetes Secrets
  - Platform-specific secret management (Railway, Render, Fly.io)

### Container Security

The Ferentin Service Edge container follows security best practices:

- Read-only root filesystem
- Non-root user execution (UID 1000)
- No package manager in runtime image
- Setuid/setgid bits removed
- Images signed with Cosign

## Reporting Security Vulnerabilities

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please email: **security@ferentin.net**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested remediation

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 5 business days
- **Resolution Timeline**: Depends on severity, typically 30-90 days

### Scope

This security policy covers:
- This repository's content
- The Ferentin Service Edge container image
- Deployment configurations and templates

For vulnerabilities in the Ferentin platform itself, please contact security@ferentin.net.

## SOC 2 Compliance

This repository is documented as an **intentional exception** in Ferentin's SOC 2 compliance program:

- **Justification**: Required for customer self-service deployments
- **Compensating Controls**: No secrets in repository, comprehensive .gitignore, placeholder-only configurations
- **Review Frequency**: Quarterly

## Contact

- **Security Issues**: security@ferentin.net
- **General Support**: support@ferentin.net
- **Documentation**: https://docs.ferentin.net

---

**Last Review**: January 2026
**Next Review**: April 2026
