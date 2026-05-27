output "eso_irsa_role_arn" {
  description = "IRSA role ARN for External Secrets Operator"
  value       = module.eso_irsa.iam_role_arn
}

output "eso_namespace" {
  description = "Namespace where ESO is installed"
  value       = helm_release.external_secrets.namespace
}
