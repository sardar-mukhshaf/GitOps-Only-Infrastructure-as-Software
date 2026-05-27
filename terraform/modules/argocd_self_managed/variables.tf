variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "argocd_version" {
  type = string
}

variable "enable_sso" {
  type = bool
}

variable "sso_client_secret_arn" {
  type    = string
  default = ""
}

variable "self_heal_enabled" {
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
