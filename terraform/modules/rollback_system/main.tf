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
# IAM Role for Rollback Lambda
# ---------------------------------------------------------------------------

resource "aws_iam_role" "rollback" {
  name = "${local.name_prefix}-rollback"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "rollback" {
  name = "${local.name_prefix}-rollback-policy"
  role = aws_iam_role.rollback.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadGitHubToken"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.github_token_secret_arn != "" ? var.github_token_secret_arn : "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${local.name_prefix}-rollback:*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Lambda Function for Automated Git Revert
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "rollback" {
  function_name = "${local.name_prefix}-rollback"
  role          = aws_iam_role.rollback.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.rollback.output_path
  source_code_hash = data.archive_file.rollback.output_base64sha256

  environment {
    variables = {
      GITHUB_TOKEN_SECRET_ARN    = var.github_token_secret_arn
      PAGERDUTY_SERVICE_KEY      = var.pagerduty_service_key
      ENVIRONMENT                = var.environment
      ENABLE_AUTO_REVERT_STAGING = tostring(var.enable_auto_revert_staging)
    }
  }

  tags = local.tags
}

data "archive_file" "rollback" {
  type        = "zip"
  output_path = "${path.module}/rollback.zip"

  source {
    content  = file("${path.module}/auto_rollback.py")
    filename = "index.py"
  }
}

# ---------------------------------------------------------------------------
# SNS Topic for ArgoCD Sync Failure Events
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "argocd_sync_failures" {
  name = "${local.name_prefix}-argocd-sync-failures"

  tags = local.tags
}

resource "aws_sns_topic_subscription" "rollback_lambda" {
  topic_arn = aws_sns_topic.argocd_sync_failures.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.rollback.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rollback.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.argocd_sync_failures.arn
}
