variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "teams_list" {
  type = list(string)
}

variable "source_repositories" {
  type = map(list(string))
}

variable "destination_namespaces" {
  type = map(list(string))
}

variable "enable_pr_preview" {
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
