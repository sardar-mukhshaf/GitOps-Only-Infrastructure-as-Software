# SAMA Compliance Mapping

This document maps the Saudi Central Bank (SAMA) Cyber Security Framework controls to components of the GitOps-Only Infrastructure as Software platform.

## 3-1: Cyber Security Governance

| SAMA Control | Platform Component | Evidence Location |
|-------------|-------------------|-------------------|
| 3-1-1 | Terraform + Atlantis | Every change is a Git commit with author attribution |
| 3-1-2 | CloudTrail + S3 Object Lock | `s3://*-audit-logs/AWSLogs/` |
| 3-1-3 | Policy Engine (Conftest + Kyverno) | `policies/conftest/`, `kubernetes/kyverno/policies/` |

## 3-2: Cyber Security Risk Management

| SAMA Control | Platform Component | Evidence Location |
|-------------|-------------------|-------------------|
| 3-2-1 | Checkov + Conftest in CI | `.github/workflows/terraform-validation.yml` |
| 3-2-2 | Drift Detection Lambda | `terraform/modules/drift_detection/`, CloudWatch Logs |
| 3-2-3 | Break-glass runbook | `docs/runbooks/break-glass.md` |

## 3-3: Cyber Security Operations

| SAMA Control | Platform Component | Evidence Location |
|-------------|-------------------|-------------------|
| 3-3-1 | ArgoCD self-healing | `gitops/argocd-apps/self-management/` |
| 3-3-2 | Automated rollback system | `terraform/modules/rollback_system/` |
| 3-3-3 | GuardDuty + Security Hub | `terraform/modules/eks_gitops/` |

## 3-4: Identity and Access Management

| SAMA Control | Platform Component | Evidence Location |
|-------------|-------------------|-------------------|
| 3-4-1 | IRSA for all EKS workloads | Every module uses IRSA, no node IAM |
| 3-4-2 | Atlantis approval requirements | `gitops/atlantis/repo-config.yaml` |
| 3-4-3 | Kyverno block-manual-secrets | `kubernetes/kyverno/policies/block-manual-secrets.yaml` |

## 3-5: Asset Management

| SAMA Control | Platform Component | Evidence Location |
|-------------|-------------------|-------------------|
| 3-5-1 | Required tags policy | `policies/conftest/terraform/required_tags.rego` |
| 3-5-2 | Terraform-docs + auto-generation | `make docs-generate` |

## 3-6: Data Protection

| SAMA Control | Platform Component | Evidence Location |
|-------------|-------------------|-------------------|
| 3-6-1 | SOPS + KMS encryption | `gitops/sops/.sops.yaml` |
| 3-6-2 | External Secrets Operator | `kubernetes/external-secrets/` |
| 3-6-3 | S3 Object Lock 7-year retention | `terraform/modules/audit_logging/` |

## 3-7: Cloud Security

| SAMA Control | Platform Component | Evidence Location |
|-------------|-------------------|-------------------|
| 3-7-1 | Private EKS endpoint | `terraform/modules/eks_gitops/` |
| 3-7-2 | VPC Flow Logs | `terraform/modules/networking/` |
| 3-7-3 | CloudTrail organization trail | `terraform/modules/audit_logging/` |

## Evidence Collection

For audit purposes, the following S3 paths contain immutable evidence:
- `s3://*-audit-logs/AWSLogs/*/CloudTrail/*/`: CloudTrail logs
- `s3://*-terraform-state/`: Terraform state with versioning
- `s3://*-flow-logs/`: VPC Flow Logs (7-year Object Lock)

Athena queries for ad-hoc audit evidence:
```sql
SELECT eventtime, eventname, useridentity.username, sourceipaddress
FROM cloudtrail_logs
WHERE eventname IN ('PutBucketPolicy', 'CreateAccessKey', 'DeleteKeyPair')
  AND eventtime > date_add('day', -90, now());
```
