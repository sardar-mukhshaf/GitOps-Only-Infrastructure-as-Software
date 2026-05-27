variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_auto_revert_staging" {
  type = bool
}

variable "github_token_secret_arn" {
  type    = string
  default = ""
}

variable "pagerduty_service_key" {
  type      = string
  default   = ""
  sensitive = true
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
