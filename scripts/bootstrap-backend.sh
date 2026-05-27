#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="${PROJECT_NAME:-gitops-platform}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap the Terraform backend (S3 + DynamoDB + KMS) for the GitOps platform.

OPTIONS:
  -p, --project-name NAME    Project name prefix (default: gitops-platform)
  -r, --region REGION        AWS region (default: eu-west-1)
  -e, --environment ENV      Environment name (default: dev)
  -h, --help                 Show this help message

EXAMPLES:
  $(basename "$0") -p myproject -r us-east-1 -e prod
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--project-name) PROJECT_NAME="$2"; shift 2 ;;
    -r|--region) AWS_REGION="$2"; shift 2 ;;
    -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

echo "=== Bootstrapping Terraform Backend ==="
echo "Project:    ${PROJECT_NAME}"
echo "Region:     ${AWS_REGION}"
echo "Environment: ${ENVIRONMENT}"

BUCKET_NAME="${PROJECT_NAME}-terraform-state-$(aws sts get-caller-identity --query Account --output text)-${AWS_REGION}"
TABLE_NAME="${PROJECT_NAME}-terraform-locks"
KEY_ALIAS="alias/${PROJECT_NAME}-terraform-state"

# Create S3 bucket
echo "Creating S3 bucket: ${BUCKET_NAME}"
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "Bucket already exists"
else
  aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${AWS_REGION}" \
    --create-bucket-configuration LocationConstraint="${AWS_REGION}" 2>/dev/null || \
  aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}"
fi

aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table
echo "Creating DynamoDB table: ${TABLE_NAME}"
if aws dynamodb describe-table --table-name "${TABLE_NAME}" >/dev/null 2>&1; then
  echo "Table already exists"
else
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
fi

# Create KMS key
echo "Creating KMS key: ${KEY_ALIAS}"
KEY_ID=$(aws kms list-aliases --query "Aliases[?AliasName=='${KEY_ALIAS}'].TargetKeyId | [0]" --output text)
if [[ "${KEY_ID}" == "None" || -z "${KEY_ID}" ]]; then
  KEY_ID=$(aws kms create-key --description "Terraform state encryption for ${PROJECT_NAME}" --query KeyMetadata.KeyId --output text)
  aws kms create-alias --alias-name "${KEY_ALIAS}" --target-key-id "${KEY_ID}"
  echo "KMS key created: ${KEY_ID}"
else
  echo "KMS key already exists: ${KEY_ID}"
fi

echo ""
echo "=== Bootstrap Complete ==="
echo "S3 Bucket:      ${BUCKET_NAME}"
echo "DynamoDB Table: ${TABLE_NAME}"
echo "KMS Key:        ${KEY_ALIAS}"
echo ""
echo "Add the following backend configuration to terraform/backend.hcl:"
cat <<EOF

bucket         = "${BUCKET_NAME}"
key            = "${ENVIRONMENT}/terraform.tfstate"
region         = "${AWS_REGION}"
encrypt        = true
dynamodb_table = "${TABLE_NAME}"
kms_key_id     = "${KEY_ALIAS}"
EOF
