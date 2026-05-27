variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "terraform_docs_version" {
  type = string
}

variable "enable_mermaid_generation" {
  type = bool
}

variable "docs_output_path" {
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
