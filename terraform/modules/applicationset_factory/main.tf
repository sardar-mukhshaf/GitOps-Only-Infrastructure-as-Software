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
# AppProject per Team
# ---------------------------------------------------------------------------

resource "kubernetes_manifest" "team_projects" {
  for_each = toset(var.teams_list)

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = each.value
      namespace = "argocd"
      annotations = {
        "argocd.argoproj.io/tracking-id" = "${each.value}:AppProject/${each.value}"
        "description"                    = "Project for ${each.value} team"
      }
    }
    spec = {
      description = "Project for ${each.value} team"
      sourceRepos = lookup(var.source_repositories, each.value, [])
      destinations = [
        for ns in lookup(var.destination_namespaces, each.value, []) : {
          namespace = ns
          server    = "https://kubernetes.default.svc"
        }
      ]
      clusterResourceWhitelist = [
        {
          group = ""
          kind  = "Namespace"
        }
      ]
      namespaceResourceWhitelist = [
        { group = "apps", kind = "Deployment" },
        { group = "apps", kind = "StatefulSet" },
        { group = "", kind = "Service" },
        { group = "", kind = "ConfigMap" },
        { group = "", kind = "Secret" },
        { group = "networking.k8s.io", kind = "Ingress" },
        { group = "autoscaling", kind = "HorizontalPodAutoscaler" }
      ]
      namespaceResourceBlacklist = [
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" }
      ]
      syncWindows = [
        {
          kind       = "deny"
          schedule   = "0 2 * * *"
          duration   = "1h"
          namespaces = ["*"]
          manualSync = true
        }
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# ApplicationSet per Team
# ---------------------------------------------------------------------------

resource "kubernetes_manifest" "team_applicationsets" {
  for_each = toset(var.teams_list)

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "${each.value}-apps"
      namespace = "argocd"
      annotations = {
        "argocd.argoproj.io/tracking-id" = "${each.value}:ApplicationSet/${each.value}-apps"
        "description"                    = "ApplicationSet for ${each.value} team services"
      }
    }
    spec = {
      generators = [
        {
          git = {
            repoURL  = lookup(var.source_repositories, each.value, [""])[0]
            revision = "HEAD"
            directories = [
              {
                path = "*/overlays/${var.environment}"
              }
            ]
          }
        }
      ]
      template = {
        metadata = {
          name = "{{path.basename}}-{{path[0]}}"
          annotations = {
            "argocd.argoproj.io/tracking-id" = "${each.value}:Application/{{path.basename}}-{{path[0]}}"
          }
        }
        spec = {
          project = each.value
          source = {
            repoURL        = lookup(var.source_repositories, each.value, [""])[0]
            targetRevision = "HEAD"
            path           = "{{path}}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{path[0]}}"
          }
          syncPolicy = {
            automated = {
              selfHeal = true
              prune    = true
            }
            retry = {
              limit = 5
              backoff = {
                duration    = "5s"
                factor      = 2
                maxDuration = "3m"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.team_projects]
}
