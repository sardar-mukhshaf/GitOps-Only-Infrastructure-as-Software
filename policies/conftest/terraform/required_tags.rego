package main

required_tags := {"Environment", "Team", "CostCenter", "Description"}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type != ""
  resource.change.after.tags
  missing := required_tags - object.keys(resource.change.after.tags)
  count(missing) > 0
  msg := sprintf("Resource %s is missing required tags: %v", [resource.address, missing])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type != ""
  not resource.change.after.tags
  msg := sprintf("Resource %s must have tags defined", [resource.address])
}
