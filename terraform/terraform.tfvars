# ---------------------------------------------------------------------------
# GitOps-Only Infrastructure as Software - Centralized Variables
# ---------------------------------------------------------------------------
# INSTRUCTIONS:
# 1. Copy this file to terraform.tfvars (remove .example if present)
# 2. Fill in ALL values below - no defaults are provided for critical fields
# 3. Run: make bootstrap
# 4. Run: make plan
# 5. Run: make apply
# ---------------------------------------------------------------------------

# Global
project_name         = "gitops-platform"
environment          = "dev"
aws_region           = "eu-west-1"
git_commit_sha       = "0000000"
resource_description = "GitOps-only infrastructure platform for regulated enterprise environments"

common_tags = {
  CostCenter = "platform-engineering"
  Team       = "platform"
  Owner      = "platform-team@example.com"
}

# Feature Flags
enable_eks                     = true
enable_atlantis                = true
enable_argocd                  = true
enable_applicationset_factory  = true
enable_secrets_sops            = true
enable_external_secrets        = true
enable_policy_engine           = true
enable_drift_detection         = true
enable_rollback_system         = true
enable_docs_generator          = true
enable_audit_logging           = true

# Networking
vpc_cidr = "10.0.0.0/16"
az_count = 3

# EKS
cluster_version                = "1.29"
cluster_endpoint_public_access = false
enable_guardduty               = true

# Atlantis
atlantis_version         = "0.27"
github_org               = "my-org"
github_app_id_secret_arn = ""
allowed_repositories     = ["my-org/infrastructure", "my-org/gitops-apps"]
webhook_secret_arn       = ""

# ArgoCD
argocd_version        = "6.7.3"
enable_sso            = false
sso_client_secret_arn = ""
self_heal_enabled     = true

# ApplicationSet Factory
teams_list             = ["backend", "data", "frontend"]
source_repositories    = {
  backend  = ["my-org/team-backend"]
  data     = ["my-org/team-data"]
  frontend = ["my-org/team-frontend"]
}
destination_namespaces = {
  backend  = ["backend", "backend-staging"]
  data     = ["data", "data-staging"]
  frontend = ["frontend", "frontend-staging"]
}
enable_pr_preview = false

# SOPS
sops_kms_key_arn_dev  = ""
sops_kms_key_arn_prod = ""
enable_key_rotation   = true

# External Secrets Operator
eso_version      = "0.9.13"
eso_refresh_interval = "1h"
eso_deletion_policy  = "Retain"

# Policy Engine
conftest_version      = "0.49.1"
opa_enabled           = false
kyverno_enabled       = true
policy_failure_action = "Enforce"

# Drift Detection
drift_check_interval = "rate(15 minutes)"
drift_auto_remediate = false
alert_sns_topic_arn  = ""
lambda_runtime       = "python3.11"

# Rollback System
enable_auto_revert_staging = true
github_token_secret_arn    = ""
pagerduty_service_key      = ""

# Docs Generator
terraform_docs_version    = "0.17.0"
enable_mermaid_generation = true
docs_output_path          = "../docs/architecture"

# Audit Logging
cloudtrail_bucket_name = ""
retention_years        = 7
enable_athena          = true
alert_email            = "security@example.com"
