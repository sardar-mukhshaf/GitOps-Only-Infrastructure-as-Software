#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify that all .enc.yaml and .enc.json files are actually SOPS encrypted.

OPTIONS:
  -h, --help    Show this help message
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

EXIT_CODE=0

for file in $(find gitops/sops -name "*.enc.yaml" -o -name "*.enc.json" 2>/dev/null); do
  if ! grep -q "sops:" "$file" 2>/dev/null; then
    echo "ERROR: $file is not SOPS encrypted"
    EXIT_CODE=1
  fi
done

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "All encrypted files are valid SOPS files"
fi

exit $EXIT_CODE
