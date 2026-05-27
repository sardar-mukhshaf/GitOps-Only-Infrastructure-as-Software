#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Trigger an automated rollback by reverting the last Terraform commit.

OPTIONS:
  -e, --environment ENV   Environment to rollback (dev, staging)
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

if [[ "${ENVIRONMENT}" == "prod" ]]; then
  echo "ERROR: Auto-rollback is not permitted in production"
  echo "Follow the break-glass procedure in docs/runbooks/break-glass.md"
  exit 1
fi

echo "=== Auto-Rollback for ${ENVIRONMENT} ==="

LAST_COMMIT=$(git log -1 --pretty=format:"%H")
LAST_MSG=$(git log -1 --pretty=format:"%s")

echo "Last commit: ${LAST_COMMIT}"
echo "Message: ${LAST_MSG}"

echo "Reverting last commit..."
git revert --no-edit "${LAST_COMMIT}"

echo "Pushing revert..."
git push origin "$(git branch --show-current)"

echo "=== Rollback complete ==="
echo "Atlantis will automatically plan the revert on the next PR"
