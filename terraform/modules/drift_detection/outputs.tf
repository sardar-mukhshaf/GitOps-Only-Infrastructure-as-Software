output "lambda_function_arn" {
  description = "ARN of the drift detection Lambda"
  value       = aws_lambda_function.drift_detection.arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for drift alerts"
  value       = local.sns_topic_arn
}
