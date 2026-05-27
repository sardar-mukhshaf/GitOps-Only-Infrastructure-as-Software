locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Name        = local.name_prefix
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    ManagedBy   = "terraform"
    Description = var.resource_description
  })

  # Enforce private endpoint in prod via validation in root variables
}

# ---------------------------------------------------------------------------
# EKS Cluster (using well-maintained community module)
# ---------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name_prefix
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Managed Node Groups
  eks_managed_node_groups = {
    system = {
      name           = "${local.name_prefix}-system"
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 4
      desired_size   = 2

      subnet_ids = var.intra_subnet_ids

      labels = {
        workload = "system"
      }

      tags = local.tags
    }

    workloads = {
      name           = "${local.name_prefix}-workloads"
      instance_types = ["m6i.xlarge", "m6i.2xlarge"]
      capacity_type  = "SPOT"
      min_size       = 2
      max_size       = 10
      desired_size   = 3

      subnet_ids = var.private_subnet_ids

      labels = {
        workload = "workloads"
      }

      tags = local.tags
    }
  }

  # Enable OIDC provider for IRSA
  enable_irsa = true

  # Tags
  tags = local.tags
}

# ---------------------------------------------------------------------------
# KMS Key for EKS Secrets Encryption
# ---------------------------------------------------------------------------

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secret encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-eks-encryption"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.name_prefix}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ---------------------------------------------------------------------------
# Enable GuardDuty for EKS if requested
# ---------------------------------------------------------------------------

resource "aws_guardduty_detector" "this" {
  count = var.enable_guardduty ? 1 : 0

  enable = true

  datasources {
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = local.tags
}

resource "aws_guardduty_organization_configuration" "this" {
  count = var.enable_guardduty ? 1 : 0

  auto_enable = true
  detector_id = aws_guardduty_detector.this[0].id

  datasources {
    kubernetes {
      audit_logs {
        auto_enable = true
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Enable Security Hub
# ---------------------------------------------------------------------------

resource "aws_securityhub_account" "this" {
  count = var.enable_guardduty ? 1 : 0
}

# ---------------------------------------------------------------------------
# Pod Security Standards: Restricted (via EKS Pod Identity or RBAC)
# Using Kyverno for enforcement (installed via policy_engine module)
# ---------------------------------------------------------------------------
