variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "eso_version" {
  type = string
}

variable "refresh_interval" {
  type = string
}

variable "deletion_policy" {
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

variable "eks_cluster_name" {
  type = string
}

variable "eks_oidc_issuer_url" {
  type = string
}
