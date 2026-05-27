package main

# Deny containers without resource limits
deny[msg] {
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg := sprintf("Container %s must have resource limits defined", [container.name])
}

deny[msg] {
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("Container %s must have memory limits defined", [container.name])
}

deny[msg] {
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.cpu
  msg := sprintf("Container %s must have CPU limits defined", [container.name])
}

# Deny containers without resource requests
deny[msg] {
  container := input.spec.template.spec.containers[_]
  not container.resources.requests
  msg := sprintf("Container %s must have resource requests defined", [container.name])
}
