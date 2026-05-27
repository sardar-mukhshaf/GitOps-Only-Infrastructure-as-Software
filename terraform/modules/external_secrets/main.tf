locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Name        = local.name_prefix
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    ManagedBy   = "terraform"
    Description = var.resource_description
  })
}

# ---------------------------------------------------------------------------
# IRSA Role for External Secrets Operator
# ---------------------------------------------------------------------------

module "eso_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_prefix}-eso"

  oidc_providers = {
    main = {
      provider_arn               = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.eks_oidc_issuer_url, "https://", "")}"
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  role_policy_arns = {
    secrets_manager = aws_iam_policy.eso.arn
  }

  tags = local.tags
}

resource "aws_iam_policy" "eso" {
  name        = "${local.name_prefix}-eso-secrets-manager"
  description = "Policy for External Secrets Operator to read AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# ---------------------------------------------------------------------------
# External Secrets Operator Helm Release
# ---------------------------------------------------------------------------

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_version
  namespace  = "external-secrets"
  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\.amazonaws\.com/role-arn"
    value = module.eso_irsa.iam_role_arn
  }

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "webhook.port"
    value = "10250"
  }

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
      }
    })
  ]
}
