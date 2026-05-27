# Break-Glass Runbook

## Purpose

This runbook documents the emergency procedure for manual AWS Console or kubectl access when automated GitOps pipelines cannot resolve a production outage.

## When to Use

- Production outage where Terraform provider is buggy or unavailable
- Critical security incident requiring immediate IAM changes
- Data recovery operations not supported by Terraform

## Approval Process

1. **Requestor** opens an emergency Slack thread in `#incidents`
2. **Approver** (second platform admin) reviews the justification
3. Both parties run: `make break-glass` and provide:
   - `--reason`: Detailed justification
   - `--user`: Requestor username
   - `--approver`: Approver username
4. The script logs the approval to CloudTrail

## Procedure

```bash
# Step 1: Request break-glass access
make break-glass -- --reason="RDS failover required" --user="alice" --approver="bob"

# Step 2: Assume the break-glass role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT:role/break-glass \
  --role-session-name alice-breakglass

# Step 3: Perform ONLY the necessary manual change

# Step 4: Document the change in the incident thread

# Step 5: Reconcile state
terraform import aws_db_instance.main <resource-id>
make plan
make apply

# Step 6: Revoke access
# (The break-glass role has a 1-hour session limit)
```

## Post-Incident

- Update this runbook if the scenario should be added to Terraform
- Review why GitOps automation failed
- Schedule a retrospective within 48 hours
