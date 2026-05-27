output "atlantis_irsa_role_arn" {
  description = "IRSA role ARN for Atlantis"
  value       = module.atlantis_irsa.iam_role_arn
}

output "atlantis_locks_table_name" {
  description = "DynamoDB table for Atlantis locks"
  value       = aws_dynamodb_table.atlantis_locks.name
}

output "atlantis_namespace" {
  description = "Namespace where Atlantis is installed"
  value       = helm_release.atlantis.namespace
}
