package terraform.analysis

import future.keywords.if
import future.keywords.in

# Deny public subnet association with sensitive resources
deny[msg] {
  some sg in input.resource_changes
  sg.type == "aws_security_group"
  sg.change.after.ingress[_].cidr_blocks[_] == "0.0.0.0/0"
  sg.change.after.ingress[_].from_port == 22
  msg := sprintf("Security group %s allows SSH from 0.0.0.0/0", [sg.address])
}

# Deny IAM roles with overly permissive policies attached
deny[msg] {
  some role in input.resource_changes
  role.type == "aws_iam_role_policy_attachment"
  role.change.after.policy_arn == "arn:aws:iam::aws:policy/AdministratorAccess"
  msg := sprintf("IAM role %s must not have AdministratorAccess attached", [role.address])
}

# Require VPC Flow Logs for all VPCs
 deny[msg] {
  some vpc in input.resource_changes
  vpc.type == "aws_vpc"
  not vpc_has_flow_logs(vpc.change.after.id)
  msg := sprintf("VPC %s must have flow logs enabled", [vpc.address])
}

vpc_has_flow_logs(vpc_id) {
  some fl in input.resource_changes
  fl.type == "aws_flow_log"
  fl.change.after.vpc_id == vpc_id
}
