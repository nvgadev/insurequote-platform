# InsureQuote Platform

Foundation for five DevOps + AI projects built on one small insurance quote app,
running on Amazon EKS in an isolated AWS sandbox account.

| Folder | What it holds |
| --- | --- |
| `infra/bootstrap/org` | Management account: sandbox guardrail SCP and monthly budget |
| `infra/bootstrap/sandbox` | Sandbox account: Terraform state bucket, GitHub OIDC provider, plan and apply roles |
| `infra/envs` | Environments (VPC, EKS, RDS), built from `nvgadev/terraform-aws-modules` *(Phase 0)* |
| `app` | InsureQuote services: web, quote-api, policy-service, notification-worker *(Phase 0)* |
| `gitops` | Helm charts and Argo CD applications *(Phase 0)* |
| `llm-gateway` | Shared Bedrock wrapper used by the AI projects *(Phase 1)* |
| `chaos` | k6 load tests, Chaos Mesh experiments, seeded test cases *(Phase 1)* |

## Related repositories

| Repository | Project |
| --- | --- |
| `terraform-aws-modules` | Reusable, versioned Terraform modules |
| `insurequote-ai-cicd` | 1 · AI-powered CI/CD pipeline |
| `insurequote-incident-copilot` | 2 · AI incident copilot |
| `insurequote-self-healer` | 3 · Self-healing Kubernetes |
| `insurequote-cost-optimizer` | 4 · AI cloud cost optimizer |
| `insurequote-security-engine` | 5 · AI cloud security engine |

## Getting started

Start with [infra/bootstrap/README.md](infra/bootstrap/README.md).

## Security model

- No long-lived AWS keys. People sign in through IAM Identity Center; GitHub Actions uses OIDC.
- Pull requests get a read-only role. Only the protected `demo` environment, after a reviewer approves, gets the apply role.
- A service control policy limits the sandbox to us-east-1, blocks large and GPU instances, and protects CloudTrail.
