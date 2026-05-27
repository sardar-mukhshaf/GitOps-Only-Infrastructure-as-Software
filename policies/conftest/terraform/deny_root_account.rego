package main

# Deny IAM policies that allow root account access
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_policy"
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  contains(statement.Principal, "arn:aws:iam::")
  contains(statement.Principal, ":root")
  msg := sprintf("IAM policy %s cannot allow root account access: %s", [resource.address, statement.Principal])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_role_policy"
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  contains(statement.Principal.AWS, ":root")
  msg := sprintf("IAM role policy %s cannot allow root account access", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_policy"
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  statement.Principal == "*"
  msg := sprintf("IAM policy %s cannot allow Principal '*'; use specific roles instead", [resource.address])
}
