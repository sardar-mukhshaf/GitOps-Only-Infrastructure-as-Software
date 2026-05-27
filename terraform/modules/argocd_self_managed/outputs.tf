output "argocd_irsa_role_arn" {
  description = "IRSA role ARN for ArgoCD"
  value       = module.argocd_irsa.iam_role_arn
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}

output "argocd_server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}
