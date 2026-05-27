# ---------------------------------------------------------------------------
# Global Variables
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project, used as a prefix for all resources"
  type        = string

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 20 && can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must be 3-20 lowercase alphanumeric characters with hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for primary deployment"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format (e.g., eu-west-1)."
  }
}

variable "git_commit_sha" {
  description = "Git commit SHA to tag all resources with"
  type        = string

  validation {
    condition     = can(regex("^[a-f0-9]{7,40}$", var.git_commit_sha))
    error_message = "git_commit_sha must be a valid Git SHA between 7 and 40 hexadecimal characters."
  }
}

variable "resource_description" {
  description = "Human-readable description for resources"
  type        = string

  validation {
    condition     = length(var.resource_description) >= 10
    error_message = "resource_description must be at least 10 characters."
  }
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags to merge into common_tags"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Feature Flags
# ---------------------------------------------------------------------------

variable "enable_eks" {
  description = "Enable EKS cluster module"
  type        = bool
  default     = true
}

variable "enable_atlantis" {
  description = "Enable Atlantis module"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Enable ArgoCD self-managed module"
  type        = bool
  default     = true
}

variable "enable_applicationset_factory" {
  description = "Enable ApplicationSet factory for team onboarding"
  type        = bool
  default     = true
}

variable "enable_secrets_sops" {
  description = "Enable SOPS + KMS secrets module"
  type        = bool
  default     = true
}

variable "enable_external_secrets" {
  description = "Enable External Secrets Operator module"
  type        = bool
  default     = true
}

variable "enable_policy_engine" {
  description = "Enable policy engine (Conftest + OPA + Kyverno)"
  type        = bool
  default     = true
}

variable "enable_drift_detection" {
  description = "Enable drift detection Lambda module"
  type        = bool
  default     = true
}

variable "enable_rollback_system" {
  description = "Enable automated rollback system module"
  type        = bool
  default     = true
}

variable "enable_docs_generator" {
  description = "Enable documentation generator module"
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Enable audit logging module (CloudTrail + S3)"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public EKS endpoint (should be false in prod)"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty for EKS"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Atlantis
# ---------------------------------------------------------------------------

variable "atlantis_version" {
  description = "Atlantis Docker image version"
  type        = string
  default     = "0.27"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_app_id_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing GitHub App ID"
  type        = string
  default     = ""
}

variable "allowed_repositories" {
  description = "List of repositories Atlantis is allowed to manage"
  type        = list(string)
  default     = []
}

variable "webhook_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing GitHub webhook HMAC secret"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# ArgoCD
# ---------------------------------------------------------------------------

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "6.7.3"
}

variable "enable_sso" {
  description = "Enable SSO integration for ArgoCD"
  type        = bool
  default     = false
}

variable "sso_client_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing SSO client secret"
  type        = string
  default     = ""
}

variable "self_heal_enabled" {
  description = "Enable ArgoCD self-healing"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# ApplicationSet Factory
# ---------------------------------------------------------------------------

variable "teams_list" {
  description = "List of team names for ApplicationSet generation"
  type        = list(string)
  default     = []
}

variable "source_repositories" {
  description = "Map of team names to allowed source repository URLs"
  type        = map(list(string))
  default     = {}
}

variable "destination_namespaces" {
  description = "Map of team names to allowed destination namespaces"
  type        = map(list(string))
  default     = {}
}

variable "enable_pr_preview" {
  description = "Enable pull-request preview environments via ApplicationSet"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# SOPS
# ---------------------------------------------------------------------------

variable "sops_kms_key_arn_dev" {
  description = "KMS key ARN for dev SOPS encryption"
  type        = string
  default     = ""
}

variable "sops_kms_key_arn_prod" {
  description = "KMS key ARN for prod SOPS encryption"
  type        = string
  default     = ""
}

variable "enable_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# External Secrets Operator
# ---------------------------------------------------------------------------

variable "eso_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.9.13"
}

variable "eso_refresh_interval" {
  description = "Default refresh interval for ExternalSecret resources"
  type        = string
  default     = "1h"
}

variable "eso_deletion_policy" {
  description = "Deletion policy for ExternalSecret resources"
  type        = string
  default     = "Retain"
}

# ---------------------------------------------------------------------------
# Policy Engine
# ---------------------------------------------------------------------------

variable "conftest_version" {
  description = "Conftest version for policy validation"
  type        = string
  default     = "0.49.1"
}

variable "opa_enabled" {
  description = "Enable OPA for complex referential policies"
  type        = bool
  default     = false
}

variable "kyverno_enabled" {
  description = "Enable Kyverno for Kubernetes admission control"
  type        = bool
  default     = true
}

variable "policy_failure_action" {
  description = "Kyverno policy failure action (Enforce or Audit)"
  type        = string
  default     = "Enforce"

  validation {
    condition     = contains(["Enforce", "Audit"], var.policy_failure_action)
    error_message = "policy_failure_action must be Enforce or Audit."
  }
}

# ---------------------------------------------------------------------------
# Drift Detection
# ---------------------------------------------------------------------------

variable "drift_check_interval" {
  description = "EventBridge schedule expression for drift detection"
  type        = string
  default     = "rate(15 minutes)"
}

variable "drift_auto_remediate" {
  description = "Enable automatic remediation of detected drift"
  type        = bool
  default     = false
}

variable "alert_sns_topic_arn" {
  description = "SNS topic ARN for drift alerts"
  type        = string
  default     = ""
}

variable "lambda_runtime" {
  description = "AWS Lambda runtime for Python functions"
  type        = string
  default     = "python3.11"
}

# ---------------------------------------------------------------------------
# Rollback System
# ---------------------------------------------------------------------------

variable "enable_auto_revert_staging" {
  description = "Enable automatic git revert for staging sync failures"
  type        = bool
  default     = true
}

variable "github_token_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing GitHub token"
  type        = string
  default     = ""
}

variable "pagerduty_service_key" {
  description = "PagerDuty service key for production alerts"
  type        = string
  default     = ""
  sensitive     = true
}

# ---------------------------------------------------------------------------
# Docs Generator
# ---------------------------------------------------------------------------

variable "terraform_docs_version" {
  description = "Terraform-docs version"
  type        = string
  default     = "0.17.0"
}

variable "enable_mermaid_generation" {
  description = "Enable Mermaid diagram generation from Terraform state"
  type        = bool
  default     = true
}

variable "docs_output_path" {
  description = "Path for generated documentation output"
  type        = string
  default     = "../docs/architecture"
}

# ---------------------------------------------------------------------------
# Audit Logging
# ---------------------------------------------------------------------------

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
  default     = ""
}

variable "retention_years" {
  description = "Retention period in years for audit logs"
  type        = number
  default     = 7
}

variable "enable_athena" {
  description = "Enable Athena for CloudTrail ad-hoc queries"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for audit alerts"
  type        = string
  default     = ""
}
