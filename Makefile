# GitOps-Only Infrastructure as Software - Makefile
# =================================================

.PHONY: help bootstrap plan apply destroy validate-policies drift-check docs-generate break-glass pre-flight

SHELL := /bin/bash
PROJECT_NAME ?= gitops-platform
AWS_REGION ?= eu-west-1
ENVIRONMENT ?= dev

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

pre-flight: ## Run pre-flight checks (tools, AWS creds, quotas)
	@bash scripts/pre-flight-checks.sh

bootstrap: pre-flight ## Bootstrap S3 backend, DynamoDB locks, and KMS keys
	@bash scripts/bootstrap-backend.sh \
		--project-name $(PROJECT_NAME) \
		--region $(AWS_REGION) \
		--environment $(ENVIRONMENT)

init: ## Initialize Terraform with remote backend
	cd terraform && terraform init -backend-config="bucket=$(PROJECT_NAME)-terraform-state-$$(aws sts get-caller-identity --query Account --output text)-$(AWS_REGION)" \
		-backend-config="key=$(ENVIRONMENT)/terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(PROJECT_NAME)-terraform-locks"

plan: init ## Run Terraform plan
	cd terraform && terraform plan -var-file=terraform.tfvars -var-file=environments/$(ENVIRONMENT)/terraform.tfvars

apply: init ## Run Terraform apply
	cd terraform && terraform apply -var-file=terraform.tfvars -var-file=environments/$(ENVIRONMENT)/terraform.tfvars

bootstrap-infra: init ## First-time bootstrap: apply networking and EKS only
	cd terraform && terraform apply \
		-var-file=terraform.tfvars \
		-var-file=environments/$(ENVIRONMENT)/terraform.tfvars \
		-target=module.networking \
		-target=module.eks_gitops

bootstrap-platform: init ## Apply remaining platform modules (ArgoCD, Atlantis, etc.)
	cd terraform && terraform apply \
		-var-file=terraform.tfvars \
		-var-file=environments/$(ENVIRONMENT)/terraform.tfvars

destroy: init ## Destroy all Terraform-managed infrastructure (USE WITH CAUTION)
	cd terraform && terraform destroy -var-file=terraform.tfvars -var-file=environments/$(ENVIRONMENT)/terraform.tfvars

validate-policies: ## Run Conftest, OPA, and Checkov against Terraform plan
	cd terraform && terraform plan -out=tfplan -input=false -lock=false
	cd terraform && terraform show -json tfplan > tfplan.json
	conftest test terraform/tfplan.json --policy policies/conftest/terraform
	checkov -f terraform/tfplan.json --framework terraform_plan

drift-check: ## Run drift detection comparing state to live AWS resources
	python3 scripts/drift-detector.py \
		--bucket $(PROJECT_NAME)-terraform-state-$$(aws sts get-caller-identity --query Account --output text)-$(AWS_REGION) \
		--key $(ENVIRONMENT)/terraform.tfstate \
		--output drift-report.json

docs-generate: ## Generate Terraform docs and architecture diagrams
	bash scripts/generate-docs.sh --output docs/architecture

break-glass: ## Emergency manual access with 4-eyes approval logging
	bash scripts/break-glass.sh

sops-rotate: ## Rotate SOPS KMS keys and re-encrypt secrets
	bash scripts/rotate-sops-keys.sh --environment $(ENVIRONMENT)

install-tools: ## Install required tools (SOPS, Conftest, etc.)
	bash scripts/install-sops.sh

fmt: ## Format all Terraform files
	terraform fmt -recursive terraform/

lint: ## Run tflint across all modules
	cd terraform && tflint --recursive --format compact
