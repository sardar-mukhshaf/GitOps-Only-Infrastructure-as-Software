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
# IRSA Role for ArgoCD
# ---------------------------------------------------------------------------

module "argocd_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_prefix}-argocd"

  oidc_providers = {
    main = {
      provider_arn               = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.eks_oidc_issuer_url, "https://", "")}"
      namespace_service_accounts = ["argocd:argocd-application-controller", "argocd:argocd-server"]
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# ArgoCD Helm Release
# ---------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      global = {
        image = {
          tag = "v2.10.0"
        }
      }

      configs = {
        cm = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "configManagementPlugins" = <<-EOT
            - name: sops-helm
              init:
                command: [sh, -c]
                args: ["apk add --no-cache sops aws-cli"]
              generate:
                command: [sh, -c]
                args: ["sops -d secrets.yaml 2>/dev/null || true; helm template . --include-crds"]
            - name: sops-kustomize
              init:
                command: [sh, -c]
                args: ["apk add --no-cache sops aws-cli"]
              generate:
                command: [sh, -c]
                args: ["sops -d secrets.yaml 2>/dev/null || true; kustomize build ."]
          EOT
        }

        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv" = <<-EOT
            p, role:dev-team, applications, sync, */*, allow
            p, role:dev-team, applications, get, */*, allow
            p, role:platform-admin, applications, *, */*, allow
            p, role:platform-admin, projects, *, *, allow
            p, role:platform-admin, repositories, *, *, allow
            g, platform-team, role:platform-admin
          EOT
        }

        params = {
          "server.insecure" = true
        }
      }

      server = {
        extraArgs = ["--insecure"]
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class" = "alb"
            "alb.ingress.kubernetes.io/scheme" = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
          }
          hosts = ["argocd.${var.project_name}.${var.environment}.example.com"]
        }
      }

      repoServer = {
        volumes = [
          {
            name = "sops"
            emptyDir = {}
          }
        ]
        volumeMounts = [
          {
            name = "sops"
            mountPath = "/usr/local/bin/sops"
          }
        ]
        initContainers = [
          {
            name = "download-sops"
            image = "alpine:3.19"
            command = ["sh", "-c"]
            args = ["wget -O /sops/sops https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64 && chmod +x /sops/sops"]
            volumeMounts = [
              {
                name = "sops"
                mountPath = "/sops"
              }
            ]
          }
        ]
      }

      notifications = {
        enabled = true
        argocdUrl = "https://argocd.${var.project_name}.${var.environment}.example.com"
        secret = {
          items = {}
        }
        notifiers = {
          service = {
            slack = {}
          }
        }
        templates = {
          template = {
            app-sync-failed = {
              message = "Application {{.app.metadata.name}} sync failed. Commit: {{.app.status.sync.revision}}"
            }
          }
        }
      }
    })
  ]
}

# ---------------------------------------------------------------------------
# ArgoCD Self-Management Application
# ---------------------------------------------------------------------------

resource "kubernetes_manifest" "argocd_self_management" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "argocd"
      namespace = "argocd"
      annotations = {
        "argocd.argoproj.io/sync-wave" = "-1"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/${var.project_name}/infrastructure.git"
        targetRevision = "HEAD"
        path           = "gitops/argocd"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          selfHeal = var.self_heal_enabled
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

  depends_on = [helm_release.argocd]
}
