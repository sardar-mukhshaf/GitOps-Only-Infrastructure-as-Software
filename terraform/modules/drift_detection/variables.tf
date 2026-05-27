variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "drift_check_interval" {
  type = string
}

variable "drift_auto_remediate" {
  type = bool
}

variable "alert_sns_topic_arn" {
  type    = string
  default = ""
}

variable "lambda_runtime" {
  type = string
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

variable "state_bucket_name" {
  type = string
}

variable "state_bucket_key" {
  type = string
}
