output "docs_bucket_name" {
  description = "S3 bucket for generated documentation"
  value       = aws_s3_bucket.docs.id
}

output "docs_bucket_arn" {
  description = "ARN of the docs S3 bucket"
  value       = aws_s3_bucket.docs.arn
}
