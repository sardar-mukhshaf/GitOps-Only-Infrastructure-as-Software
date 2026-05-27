output "team_projects" {
  description = "List of created ArgoCD AppProjects"
  value       = [for k, v in kubernetes_manifest.team_projects : k]
}

output "team_applicationsets" {
  description = "List of created ArgoCD ApplicationSets"
  value       = [for k, v in kubernetes_manifest.team_applicationsets : k]
}
