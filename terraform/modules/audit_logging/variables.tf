variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cloudtrail_bucket_name" {
  type = string
}

variable "retention_years" {
  type = number
}

variable "enable_athena" {
  type = bool
}

variable "alert_email" {
  type    = string
  default = ""
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
