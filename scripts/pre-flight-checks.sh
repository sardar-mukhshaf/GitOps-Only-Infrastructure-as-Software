#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run pre-flight checks before deploying the GitOps platform.

OPTIONS:
  -h, --help    Show this help message
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

echo "=== Pre-Flight Checks ==="

# Check AWS credentials
echo -n "AWS credentials... "
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "FAILED"
  echo "Error: AWS credentials not configured or invalid"
  exit 1
fi
echo "OK"

# Check required tools
check_tool() {
  local tool=$1
  local min_version=${2:-}
  echo -n "${tool}... "
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "MISSING"
    echo "Error: ${tool} is required but not installed"
    return 1
  fi
  if [[ -n "${min_version}" ]]; then
    local version
    version=$(${tool} version 2>/dev/null | head -1 || echo "unknown")
    echo "OK (${version})"
  else
    echo "OK"
  fi
}

check_tool terraform "1.7.0"
check_tool kubectl
check_tool helm
check_tool sops
check_tool conftest
check_tool tflint
check_tool checkov
check_tool python3
check_tool aws

# Check service quotas
echo "Checking service quotas..."
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
EKS_QUOTA=$(aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C --query Quota.Value --output text 2>/dev/null || echo "unknown")
echo "  EKS clusters per region: ${EKS_QUOTA}"

# Check GitHub CLI (optional)
if command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI... OK"
else
  echo "GitHub CLI... MISSING (optional)"
fi

echo ""
echo "=== All Pre-Flight Checks Passed ==="
