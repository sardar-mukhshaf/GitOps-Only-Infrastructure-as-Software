package main

# Deny containers using :latest tag
deny[msg] {
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container %s must not use :latest image tag", [container.name])
}

deny[msg] {
  container := input.spec.template.spec.initContainers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Init container %s must not use :latest image tag", [container.name])
}

# Deny containers without explicit tag
deny[msg] {
  container := input.spec.template.spec.containers[_]
  not contains(container.image, ":")
  msg := sprintf("Container %s must specify an explicit image tag", [container.name])
}
