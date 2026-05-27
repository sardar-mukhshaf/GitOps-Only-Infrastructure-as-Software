#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate documentation from Terraform state and modules.

OPTIONS:
  -o, --output PATH    Output directory for generated docs (default: docs/architecture)
  -h, --help           Show this help message
EOF
}

OUTPUT_DIR="${PROJECT_ROOT}/docs/architecture"

while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

mkdir -p "${OUTPUT_DIR}"

echo "=== Generating Terraform Module Documentation ==="

for module_dir in "${PROJECT_ROOT}/terraform/modules"/*; do
  if [[ -d "${module_dir}" ]]; then
    module_name=$(basename "${module_dir}")
    echo "Processing module: ${module_name}"
    terraform-docs markdown table "${module_dir}" > "${OUTPUT_DIR}/${module_name}-docs.md" 2>/dev/null || \
      echo "terraform-docs not available for ${module_name}, skipping"
  fi
done

echo "=== Generating Architecture Diagrams ==="

cd "${PROJECT_ROOT}/terraform"
terraform show -json > /tmp/terraform-state.json 2>/dev/null || echo "Terraform state not available, skipping diagram generation"

python3 "${SCRIPT_DIR}/generate-architecture-docs.py" \
  --state /tmp/terraform-state.json \
  --output "${OUTPUT_DIR}/architecture-diagrams.md" 2>/dev/null || \
  echo "Architecture diagram generation skipped"

echo "=== Documentation Generation Complete ==="
echo "Output: ${OUTPUT_DIR}"
