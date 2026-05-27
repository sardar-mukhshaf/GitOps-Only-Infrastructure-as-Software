package main

# Deny Kubernetes resources without description annotation
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "kubernetes_manifest"
  resource.change.after.manifest.metadata.annotations.description == ""
  msg := sprintf("Kubernetes manifest %s must have metadata.annotations.description", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "kubernetes_manifest"
  not resource.change.after.manifest.metadata.annotations.description
  msg := sprintf("Kubernetes manifest %s must have metadata.annotations.description defined", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "kubernetes_manifest"
  not resource.change.after.manifest.metadata.annotations["managed-by"]
  msg := sprintf("Kubernetes manifest %s must have metadata.annotations.managed-by defined", [resource.address])
}
