output "kyverno_namespace" {
  description = "Namespace where Kyverno is installed"
  value       = var.kyverno_enabled ? helm_release.kyverno[0].namespace : ""
}

output "conftest_version" {
  description = "Conftest version for policy validation"
  value       = var.conftest_version
}

output "opa_enabled" {
  description = "Whether OPA is enabled"
  value       = var.opa_enabled
}
