package main

# Deny S3 buckets with public ACL
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_public_access_block"
  resource.change.after.block_public_acls == false
  msg := sprintf("S3 bucket public access block must block public ACLs: %s", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_public_access_block"
  resource.change.after.block_public_policy == false
  msg := sprintf("S3 bucket public access block must block public policies: %s", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_acl"
  resource.change.after.acl == "public-read"
  msg := sprintf("S3 bucket ACL cannot be public-read: %s", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_acl"
  resource.change.after.acl == "public-read-write"
  msg := sprintf("S3 bucket ACL cannot be public-read-write: %s", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_policy"
  contains(lower(resource.change.after.policy), "principal")
  contains(lower(resource.change.after.policy), "*")
  msg := sprintf("S3 bucket policy cannot allow public access with Principal '*': %s", [resource.address])
}
