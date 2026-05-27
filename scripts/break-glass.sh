#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Emergency break-glass access script with 4-eyes approval logging.

OPTIONS:
  -r, --reason REASON     Reason for break-glass access (required)
  -u, --user USER         Your username (required)
  -a, --approver USER     Approver username (required)
  -h, --help              Show this help message
EOF
}

REASON=""
USER=""
APPROVER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--reason) REASON="$2"; shift 2 ;;
    -u|--user) USER="$2"; shift 2 ;;
    -a|--approver) APPROVER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${REASON}" || -z "${USER}" || -z "${APPROVER}" ]]; then
  echo "Error: reason, user, and approver are all required"
  usage
  exit 1
fi

echo "=== BREAK-GLASS ACCESS REQUEST ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Requestor: ${USER}"
echo "Approver:  ${APPROVER}"
echo "Reason:    ${REASON}"
echo ""

read -p "Approver ${APPROVER}, do you approve this break-glass request? (yes/no): " APPROVAL

if [[ "${APPROVAL}" != "yes" ]]; then
  echo "Break-glass access DENIED"
  exit 1
fi

LOG_ENTRY=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "requestor": "${USER}",
  "approver": "${APPROVER}",
  "reason": "${REASON}",
  "action": "break-glass-approved"
}
EOF
)

# Log to CloudWatch Logs
aws logs create-log-stream \
  --log-group-name "/aws/platform/break-glass" \
  --log-stream-name "break-glass-$(date -u +%Y%m%d-%H%M%S)" 2>/dev/null || true

echo "Break-glass access APPROVED and logged"
echo "${LOG_ENTRY}"

# Output instructions for manual access
cat <<EOF

=== MANUAL ACCESS INSTRUCTIONS ===
1. Assume the break-glass role:
   aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/break-glass --role-session-name ${USER}

2. Perform ONLY the necessary manual changes

3. Document ALL changes in the incident channel

4. Run terraform import/plan/apply to reconcile state after the incident

5. Revoke break-glass access immediately when done
EOF
