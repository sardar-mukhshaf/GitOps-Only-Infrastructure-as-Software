output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = aws_cloudtrail.this.name
}

output "audit_bucket_name" {
  description = "S3 bucket for audit logs"
  value       = aws_s3_bucket.audit.id
}

output "security_alerts_topic_arn" {
  description = "SNS topic for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}

output "athena_database" {
  description = "Athena database for audit queries"
  value       = var.enable_athena ? aws_athena_database.audit[0].name : ""
}
