# Drift Remediation Runbook

## Detecting Drift

Run `make drift-check` to compare Terraform state with live AWS resources.

## Types of Drift

| Type | Example | Severity |
|------|---------|----------|
| Missing | Resource deleted from AWS console | Critical |
| Modified | Security group rules changed | High |
| Tag drift | Tags added/removed manually | Medium |

## Auto-Remediation

In `dev` and `staging`, drift auto-remediation can be enabled:
```bash
# Set in terraform.tfvars
drift_auto_remediate = true
```

This triggers an Atlantis plan/apply to reconcile the drift.

## Manual Remediation

1. Run `make drift-check` to generate `drift-report.json`
2. Review the report for false positives (expected changes)
3. For true drift:
   - If resource was deleted: `terraform state rm <address>` then re-apply
   - If resource was modified: `terraform import <address> <id>` then re-apply
   - If tags drifted: Update tags in Terraform and apply
4. Verify with `make plan` that no unexpected changes remain

## Preventing Future Drift

- Enable SCPs to deny manual changes in production
- Use AWS Config rules for compliance monitoring
- Ensure all team members understand GitOps workflow
