variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "sops_kms_key_arn_dev" {
  type    = string
  default = ""
}

variable "sops_kms_key_arn_prod" {
  type    = string
  default = ""
}

variable "enable_key_rotation" {
  type = bool
}

variable "git_commit_sha" {
  type = string
}

variable "resource_description" {
  type = string
}

variable "common_tags" {
  type = map(string)
}
