# ---------------------------------------------------------------------------
# Local Values
# ---------------------------------------------------------------------------

locals {
  project_name_safe = replace(var.project_name, "-", "")
  env               = var.environment
  full_name         = "${var.project_name}-${local.env}"

  common_tags = merge(var.common_tags, var.tags, {
    Project     = var.project_name
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    ManagedBy   = "terraform"
    Description = var.resource_description
  })

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# ---------------------------------------------------------------------------
# Validation: EKS must be enabled if K8s-dependent modules are enabled
# ---------------------------------------------------------------------------

resource "null_resource" "validate_eks_prerequisite" {
  count = (
    !var.enable_eks && (
      var.enable_atlantis || var.enable_argocd || var.enable_external_secrets || var.enable_policy_engine
    )
  ) ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: enable_eks must be true when K8s-dependent modules are enabled' && exit 1"
  }
}

# ---------------------------------------------------------------------------
# Module: Networking
# ---------------------------------------------------------------------------

module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  availability_zones   = local.azs
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
  common_tags          = local.common_tags
}

# ---------------------------------------------------------------------------
# Module: EKS GitOps
# ---------------------------------------------------------------------------

module "eks_gitops" {
  source = "./modules/eks_gitops"

  project_name                   = var.project_name
  environment                    = var.environment
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = var.cluster_endpoint_public_access
  enable_guardduty               = var.enable_guardduty
  git_commit_sha                 = var.git_commit_sha
  resource_description           = var.resource_description
  common_tags                    = local.common_tags
  vpc_id                         = module.networking.vpc_id
  private_subnet_ids             = module.networking.private_subnet_ids
  public_subnet_ids              = module.networking.public_subnet_ids
  intra_subnet_ids               = module.networking.intra_subnet_ids

  count = var.enable_eks ? 1 : 0
}

# ---------------------------------------------------------------------------
# Module: Secrets SOPS
# ---------------------------------------------------------------------------

module "secrets_sops" {
  source = "./modules/secrets_sops"

  project_name          = var.project_name
  environment           = var.environment
  sops_kms_key_arn_dev  = var.sops_kms_key_arn_dev
  sops_kms_key_arn_prod = var.sops_kms_key_arn_prod
  enable_key_rotation   = var.enable_key_rotation
  git_commit_sha        = var.git_commit_sha
  resource_description  = var.resource_description
  common_tags           = local.common_tags

  count = var.enable_secrets_sops ? 1 : 0
}

# ---------------------------------------------------------------------------
# Module: External Secrets Operator
# ---------------------------------------------------------------------------

module "external_secrets" {
  source = "./modules/external_secrets"

  project_name         = var.project_name
  environment          = var.environment
  eso_version          = var.eso_version
  refresh_interval     = var.eso_refresh_interval
  deletion_policy      = var.eso_deletion_policy
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
  common_tags          = local.common_tags
  eks_cluster_name     = var.enable_eks ? module.eks_gitops[0].cluster_name : ""
  eks_oidc_issuer_url  = var.enable_eks ? module.eks_gitops[0].oidc_issuer_url : ""

  count = var.enable_external_secrets && var.enable_eks ? 1 : 0

  depends_on = [module.eks_gitops]
}

# ---------------------------------------------------------------------------
# Module: Policy Engine (Kyverno installed here, Conftest/OPA are CLI-side)
# ---------------------------------------------------------------------------

module "policy_engine" {
  source = "./modules/policy_engine"

  project_name          = var.project_name
  environment           = var.environment
  conftest_version      = var.conftest_version
  opa_enabled           = var.opa_enabled
  kyverno_enabled       = var.kyverno_enabled
  policy_failure_action = var.policy_failure_action
  git_commit_sha        = var.git_commit_sha
  resource_description  = var.resource_description
  common_tags           = local.common_tags
  eks_cluster_name      = var.enable_eks ? module.eks_gitops[0].cluster_name : ""
  eks_oidc_issuer_url   = var.enable_eks ? module.eks_gitops[0].oidc_issuer_url : ""

  count = var.enable_policy_engine && var.enable_eks ? 1 : 0

  depends_on = [module.eks_gitops, module.external_secrets]
}

# ---------------------------------------------------------------------------
# Module: ArgoCD Self-Managed
# ---------------------------------------------------------------------------

module "argocd_self_managed" {
  source = "./modules/argocd_self_managed"

  project_name          = var.project_name
  environment           = var.environment
  argocd_version        = var.argocd_version
  enable_sso            = var.enable_sso
  sso_client_secret_arn = var.sso_client_secret_arn
  self_heal_enabled     = var.self_heal_enabled
  git_commit_sha        = var.git_commit_sha
  resource_description  = var.resource_description
  common_tags           = local.common_tags
  eks_cluster_name      = var.enable_eks ? module.eks_gitops[0].cluster_name : ""
  eks_oidc_issuer_url   = var.enable_eks ? module.eks_gitops[0].oidc_issuer_url : ""
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids

  count = var.enable_argocd && var.enable_eks ? 1 : 0

  depends_on = [module.eks_gitops, module.policy_engine]
}

# ---------------------------------------------------------------------------
# Module: Atlantis
# ---------------------------------------------------------------------------

module "atlantis" {
  source = "./modules/atlantis"

  project_name             = var.project_name
  environment              = var.environment
  atlantis_version         = var.atlantis_version
  github_org               = var.github_org
  github_app_id_secret_arn = var.github_app_id_secret_arn
  allowed_repositories     = var.allowed_repositories
  webhook_secret_arn       = var.webhook_secret_arn
  git_commit_sha           = var.git_commit_sha
  resource_description     = var.resource_description
  common_tags              = local.common_tags
  eks_cluster_name         = var.enable_eks ? module.eks_gitops[0].cluster_name : ""
  eks_oidc_issuer_url      = var.enable_eks ? module.eks_gitops[0].oidc_issuer_url : ""
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids

  count = var.enable_atlantis && var.enable_eks ? 1 : 0

  depends_on = [module.eks_gitops, module.argocd_self_managed]
}

# ---------------------------------------------------------------------------
# Module: ApplicationSet Factory
# ---------------------------------------------------------------------------

module "applicationset_factory" {
  source = "./modules/applicationset_factory"

  project_name           = var.project_name
  environment            = var.environment
  teams_list             = var.teams_list
  source_repositories    = var.source_repositories
  destination_namespaces = var.destination_namespaces
  enable_pr_preview      = var.enable_pr_preview
  git_commit_sha         = var.git_commit_sha
  resource_description   = var.resource_description
  common_tags            = local.common_tags

  count = var.enable_applicationset_factory && var.enable_eks ? 1 : 0

  depends_on = [module.argocd_self_managed]
}

# ---------------------------------------------------------------------------
# Module: Drift Detection
# ---------------------------------------------------------------------------

module "drift_detection" {
  source = "./modules/drift_detection"

  project_name         = var.project_name
  environment          = var.environment
  drift_check_interval = var.drift_check_interval
  drift_auto_remediate = var.drift_auto_remediate
  alert_sns_topic_arn  = var.alert_sns_topic_arn
  lambda_runtime       = var.lambda_runtime
  git_commit_sha       = var.git_commit_sha
  resource_description = var.resource_description
  common_tags          = local.common_tags
  state_bucket_name    = aws_s3_bucket.terraform_state.id
  state_bucket_key     = "${var.environment}/terraform.tfstate"

  count = var.enable_drift_detection ? 1 : 0
}

# ---------------------------------------------------------------------------
# Module: Rollback System
# ---------------------------------------------------------------------------

module "rollback_system" {
  source = "./modules/rollback_system"

  project_name               = var.project_name
  environment                = var.environment
  enable_auto_revert_staging = var.enable_auto_revert_staging
  github_token_secret_arn    = var.github_token_secret_arn
  pagerduty_service_key      = var.pagerduty_service_key
  git_commit_sha             = var.git_commit_sha
  resource_description       = var.resource_description
  common_tags                = local.common_tags

  count = var.enable_rollback_system ? 1 : 0
}

# ---------------------------------------------------------------------------
# Module: Docs Generator
# ---------------------------------------------------------------------------

module "docs_generator" {
  source = "./modules/docs_generator"

  project_name              = var.project_name
  environment               = var.environment
  terraform_docs_version    = var.terraform_docs_version
  enable_mermaid_generation = var.enable_mermaid_generation
  docs_output_path          = var.docs_output_path
  git_commit_sha            = var.git_commit_sha
  resource_description      = var.resource_description
  common_tags               = local.common_tags

  count = var.enable_docs_generator ? 1 : 0
}

# ---------------------------------------------------------------------------
# Module: Audit Logging
# ---------------------------------------------------------------------------

module "audit_logging" {
  source = "./modules/audit_logging"

  project_name           = var.project_name
  environment            = var.environment
  cloudtrail_bucket_name = var.cloudtrail_bucket_name != "" ? var.cloudtrail_bucket_name : "${var.project_name}-audit-logs-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  retention_years        = var.retention_years
  enable_athena          = var.enable_athena
  alert_email            = var.alert_email
  git_commit_sha         = var.git_commit_sha
  resource_description   = var.resource_description
  common_tags            = local.common_tags

  count = var.enable_audit_logging ? 1 : 0
}
