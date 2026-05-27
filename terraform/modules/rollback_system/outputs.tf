output "rollback_lambda_arn" {
  description = "ARN of the rollback Lambda"
  value       = aws_lambda_function.rollback.arn
}

output "argocd_sync_failures_topic_arn" {
  description = "SNS topic for ArgoCD sync failures"
  value       = aws_sns_topic.argocd_sync_failures.arn
}
