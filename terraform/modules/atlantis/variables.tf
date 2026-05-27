variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "atlantis_version" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_app_id_secret_arn" {
  type    = string
  default = ""
}

variable "allowed_repositories" {
  type = list(string)
}

variable "webhook_secret_arn" {
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

variable "eks_cluster_name" {
  type = string
}

variable "eks_oidc_issuer_url" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}
