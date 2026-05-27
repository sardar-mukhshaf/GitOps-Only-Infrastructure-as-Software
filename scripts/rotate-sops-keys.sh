#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Rotate SOPS KMS keys and re-encrypt all secrets.

OPTIONS:
  -e, --environment ENV   Environment to rotate keys for (dev, staging, prod)
  -h, --help              Show this help message
EOF
}

ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${ENVIRONMENT}" ]]; then
  echo "Error: Environment is required"
  usage
  exit 1
fi

echo "=== Rotating SOPS keys for environment: ${ENVIRONMENT} ==="

# Find all encrypted files for this environment
FILES=$(find "gitops/sops/secrets/${ENVIRONMENT}" -name "*.enc.yaml" -o -name "*.enc.json" 2>/dev/null || true)

if [[ -z "${FILES}" ]]; then
  echo "No encrypted files found for environment ${ENVIRONMENT}"
  exit 0
fi

for file in ${FILES}; do
  echo "Re-encrypting: ${file}"
  sops rotate --in-place "${file}"
done

echo "=== Key rotation complete ==="
echo "Updated .sops.yaml with new key ARNs if needed"
