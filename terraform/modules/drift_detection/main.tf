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
# SNS Topic for Drift Alerts (if not provided)
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "drift_alerts" {
  count = var.alert_sns_topic_arn == "" ? 1 : 0

  name = "${local.name_prefix}-drift-alerts"

  tags = local.tags
}

locals {
  sns_topic_arn = var.alert_sns_topic_arn != "" ? var.alert_sns_topic_arn : aws_sns_topic.drift_alerts[0].arn
}

# ---------------------------------------------------------------------------
# IAM Role for Drift Detection Lambda
# ---------------------------------------------------------------------------

resource "aws_iam_role" "drift_detection" {
  name = "${local.name_prefix}-drift-detection"

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

resource "aws_iam_role_policy" "drift_detection" {
  name = "${local.name_prefix}-drift-detection-policy"
  role = aws_iam_role.drift_detection.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadTerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*"
        ]
      },
      {
        Sid    = "DescribeAWSResources"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListAttachedRolePolicies",
          "s3:ListBucket",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "route53:ListResourceRecordSets",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "PublishSNS"
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = local.sns_topic_arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${local.name_prefix}-drift-detection:*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Lambda Function for Drift Detection
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "drift_detection" {
  function_name = "${local.name_prefix}-drift-detection"
  role          = aws_iam_role.drift_detection.arn
  handler       = "index.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = 300
  memory_size   = 512

  filename         = data.archive_file.drift_detection.output_path
  source_code_hash = data.archive_file.drift_detection.output_base64sha256

  environment {
    variables = {
      STATE_BUCKET_NAME = var.state_bucket_name
      STATE_BUCKET_KEY  = var.state_bucket_key
      SNS_TOPIC_ARN     = local.sns_topic_arn
      AUTO_REMEDIATE    = tostring(var.drift_auto_remediate)
      ENVIRONMENT       = var.environment
    }
  }

  tags = local.tags
}

data "archive_file" "drift_detection" {
  type        = "zip"
  output_path = "${path.module}/drift_detection.zip"

  source {
    content  = file("${path.module}/drift_detector.py")
    filename = "index.py"
  }
}

# ---------------------------------------------------------------------------
# EventBridge Schedule
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "drift_detection" {
  name                = "${local.name_prefix}-drift-detection"
  description         = "Trigger drift detection Lambda"
  schedule_expression = var.drift_check_interval

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "drift_detection" {
  rule = aws_cloudwatch_event_rule.drift_detection.name
  arn  = aws_lambda_function.drift_detection.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.drift_detection.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.drift_detection.arn
}
