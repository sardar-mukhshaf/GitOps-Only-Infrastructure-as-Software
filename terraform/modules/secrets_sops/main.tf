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
# KMS Key for SOPS (dev)
# ---------------------------------------------------------------------------

resource "aws_kms_key" "sops_dev" {
  count = var.sops_kms_key_arn_dev == "" ? 1 : 0

  description             = "KMS key for SOPS dev environment encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Atlantis Role"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Service" = "atlantis"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-sops-dev"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "sops_dev" {
  count = var.sops_kms_key_arn_dev == "" ? 1 : 0

  name          = "alias/${local.name_prefix}-sops-dev"
  target_key_id = aws_kms_key.sops_dev[0].key_id
}

# ---------------------------------------------------------------------------
# KMS Key for SOPS (prod)
# ---------------------------------------------------------------------------

resource "aws_kms_key" "sops_prod" {
  count = var.sops_kms_key_arn_prod == "" ? 1 : 0

  description             = "KMS key for SOPS prod environment encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = var.enable_key_rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Atlantis Role"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Service" = "atlantis"
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-sops-prod"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "sops_prod" {
  count = var.sops_kms_key_arn_prod == "" ? 1 : 0

  name          = "alias/${local.name_prefix}-sops-prod"
  target_key_id = aws_kms_key.sops_prod[0].key_id
}
