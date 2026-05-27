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
# IRSA Role for Atlantis
# ---------------------------------------------------------------------------

module "atlantis_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_prefix}-atlantis"

  oidc_providers = {
    main = {
      provider_arn               = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.eks_oidc_issuer_url, "https://", "")}"
      namespace_service_accounts = ["atlantis:atlantis"]
    }
  }

  role_policy_arns = {
    terraform_backend = aws_iam_policy.atlantis.arn
  }

  tags = local.tags
}

resource "aws_iam_policy" "atlantis" {
  name        = "${local.name_prefix}-atlantis"
  description = "Policy for Atlantis to access Terraform backend and AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::*terraform-state*",
          "arn:aws:s3:::*terraform-state*/*"
        ]
      },
      {
        Sid    = "DynamoDBLocks"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/*terraform-locks*"
      },
      {
        Sid    = "EC2Read"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# ---------------------------------------------------------------------------
# DynamoDB Table for Atlantis Project Locks
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "atlantis_locks" {
  name         = "${local.name_prefix}-atlantis-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-atlantis-locks"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Atlantis Helm Release
# ---------------------------------------------------------------------------

resource "helm_release" "atlantis" {
  name       = "atlantis"
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = "5.0.0"
  namespace  = "atlantis"
  create_namespace = true

  set {
    name  = "image.tag"
    value = var.atlantis_version
  }

  set {
    name  = "serviceAccount.annotations.eks\.amazonaws\.com/role-arn"
    value = module.atlantis_irsa.iam_role_arn
  }

  set {
    name  = "orgWhitelist"
    value = join(",", var.allowed_repositories)
  }

  values = [
    yamlencode({
      github = {
        user  = "atlantis-bot"
        tokenSecretName = "atlantis-github-token"
      }

      environment = {
        ATLANTIS_WRITE_GIT_CREDS = "true"
        ATLANTIS_REPO_ALLOWLIST  = join(",", var.allowed_repositories)
        ATLANTIS_DEFAULT_TF_VERSION = "1.7.0"
      }

      volumeClaim = {
        enabled = true
        size    = "5Gi"
        storageClassName = "gp2"
      }

      resources = {
        requests = {
          cpu    = "500m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "2000m"
          memory = "2Gi"
        }
      }

      ingress = {
        enabled = true
        annotations = {
          "kubernetes.io/ingress.class" = "alb"
          "alb.ingress.kubernetes.io/scheme" = "internet-facing"
          "alb.ingress.kubernetes.io/target-type" = "ip"
        }
        hosts = [
          {
            host = "atlantis.${var.project_name}.${var.environment}.example.com"
            paths = [
              {
                path = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
      }
    })
  ]

  depends_on = [aws_dynamodb_table.atlantis_locks]
}
