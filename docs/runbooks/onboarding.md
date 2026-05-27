# Team Onboarding Runbook

## New Team Member Checklist

### Day 1: Access Setup

- [ ] AWS SSO access provisioned
- [ ] GitHub organization invite sent
- [ ] Added to `platform-team` GitHub group
- [ ] Added to Slack channels: `#platform`, `#incidents`, `#gitops-alerts`
- [ ] PagerDuty rotation configured (for on-call engineers)

### Day 2: Tool Installation

```bash
# Clone the platform repository
git clone https://github.com/my-org/gitops-platform.git
cd gitops-platform

# Install tools
make install-tools
make pre-flight
```

### Day 3: GitOps Workflow Training

1. **Read the README** (start with "What is this project")
2. **Review Atlantis workflow**: Open any merged PR and study the plan/apply comments
3. **Review ArgoCD**: Log in to the ArgoCD UI and explore applications
4. **Practice SOPS encryption**:
   ```bash
   sops --encrypt --in-place gitops/sops/secrets/dev/example.yaml
   ```

### Day 4: First Change

Make a documentation-only change to practice the full pipeline:
1. Create a branch
2. Edit `docs/runbooks/onboarding.md`
3. Open a PR
4. Watch Atlantis run `terraform plan` (no infra changes expected)
5. Get approval and merge

### Week 2: Team Infrastructure

For platform engineers, proceed to:
- Configure `terraform.tfvars` for your environment
- Run `make bootstrap`
- Deploy base infrastructure with `make plan && make apply`
- Configure GitHub webhooks for Atlantis
- Test end-to-end with a small Terraform change

## Application Team Onboarding

### Step 1: Repository Setup

Create a new repo using the standard template:
```bash
git clone https://github.com/my-org/team-templates.git
cp -r team-templates/standard-service my-team-app
cd my-team-app
```

### Step 2: ArgoCD Project Registration

Add your team to `terraform.tfvars`:
```hcl
teams_list = ["backend", "data", "my-new-team"]
source_repositories = {
  my-new-team = ["https://github.com/my-org/my-new-team"]
}
destination_namespaces = {
  my-new-team = ["my-new-team", "my-new-team-staging"]
}
```

### Step 3: Deploy via ApplicationSet

Push your repo. The ApplicationSet will automatically detect your overlays.
