package main

# Deny EBS volumes without encryption
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_ebs_volume"
  not resource.change.after.encrypted
  msg := sprintf("EBS volume must be encrypted: %s", [resource.address])
}

# Deny RDS instances without encryption
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_db_instance"
  not resource.change.after.storage_encrypted
  msg := sprintf("RDS instance must have storage encryption enabled: %s", [resource.address])
}

# Deny S3 buckets without default encryption
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  not resource.change.after.server_side_encryption_configuration
  msg := sprintf("S3 bucket must have default encryption configured: %s", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_server_side_encryption_configuration"
  count(resource.change.after.rule) == 0
  msg := sprintf("S3 bucket encryption configuration must have at least one rule: %s", [resource.address])
}
