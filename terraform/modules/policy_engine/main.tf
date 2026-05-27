locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Name        = local.name_prefix
    Environment = var.environment
    GitCommit   = var.git_commit_sha
    ManagedBy   = "terraform"
    Description = var.resource_description
  })
}

# ---------------------------------------------------------------------------
# Kyverno Helm Release
# ---------------------------------------------------------------------------

resource "helm_release" "kyverno" {
  count = var.kyverno_enabled ? 1 : 0

  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno"
  chart      = "kyverno"
  version    = "3.1.4"
  namespace  = "kyverno"
  create_namespace = true

  set {
    name  = "replicaCount"
    value = "3"
  }

  set {
    name  = "admissionController.replicas"
    value = "3"
  }

  set {
    name  = "backgroundController.replicas"
    value = "2"
  }

  set {
    name  = "cleanupController.replicas"
    value = "2"
  }

  set {
    name  = "reportsController.replicas"
    value = "2"
  }

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
      }
      config = {
        webhooks = [
          {
            namespaceSelector = {
              matchExpressions = [
                {
                  key      = "kubernetes.io/metadata.name"
                  operator = "NotIn"
                  values   = ["kyverno", "kube-system"]
                }
              ]
            }
          }
        ]
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# Kyverno Policies (deployed as Helm values or Kubernetes manifests)
# Since these are K8s resources, they can be applied via ArgoCD for GitOps
# Here we ensure the namespace and basic RBAC exist
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "kyverno" {
  count = var.kyverno_enabled ? 1 : 0

  metadata {
    name = "kyverno"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
    }
  }

  depends_on = [helm_release.kyverno]
}
