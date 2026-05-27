terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "team_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type = map(string)
  default = {}
}

locals {
  tags = merge(var.common_tags, {
    Team        = var.team_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_s3_bucket" "team_bucket" {
  bucket = "${var.team_name}-${var.environment}-artifacts"

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "team_bucket" {
  bucket = aws_s3_bucket.team_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "team_bucket" {
  bucket = aws_s3_bucket.team_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
