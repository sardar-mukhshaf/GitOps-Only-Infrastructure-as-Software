output "bucket_name" {
  description = "Team S3 bucket name"
  value       = aws_s3_bucket.team_bucket.id
}

output "bucket_arn" {
  description = "Team S3 bucket ARN"
  value       = aws_s3_bucket.team_bucket.arn
}
