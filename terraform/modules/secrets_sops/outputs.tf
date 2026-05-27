output "sops_kms_key_arn_dev" {
  description = "KMS key ARN for dev SOPS encryption"
  value       = var.sops_kms_key_arn_dev != "" ? var.sops_kms_key_arn_dev : aws_kms_key.sops_dev[0].arn
}

output "sops_kms_key_arn_prod" {
  description = "KMS key ARN for prod SOPS encryption"
  value       = var.sops_kms_key_arn_prod != "" ? var.sops_kms_key_arn_prod : aws_kms_key.sops_prod[0].arn
}

output "sops_kms_key_id_dev" {
  description = "KMS key ID for dev SOPS encryption"
  value       = var.sops_kms_key_arn_dev != "" ? var.sops_kms_key_arn_dev : aws_kms_key.sops_dev[0].key_id
}

output "sops_kms_key_id_prod" {
  description = "KMS key ID for prod SOPS encryption"
  value       = var.sops_kms_key_arn_prod != "" ? var.sops_kms_key_arn_prod : aws_kms_key.sops_prod[0].key_id
}
