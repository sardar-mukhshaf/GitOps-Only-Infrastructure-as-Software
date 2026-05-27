#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Mozilla SOPS with AWS KMS integration.

OPTIONS:
  -v, --version VERSION   SOPS version to install (default: 3.8.1)
  -h, --help              Show this help message
EOF
}

VERSION="3.8.1"

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--version) VERSION="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case ${ARCH} in
  x86_64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
esac

URL="https://github.com/getsops/sops/releases/download/v${VERSION}/sops-v${VERSION}.${OS}.${ARCH}"
DEST="/usr/local/bin/sops"

echo "Installing SOPS ${VERSION}..."
echo "Downloading from: ${URL}"

curl -Lo /tmp/sops "${URL}"
chmod +x /tmp/sops

if [[ -w /usr/local/bin ]]; then
  mv /tmp/sops "${DEST}"
else
  sudo mv /tmp/sops "${DEST}"
fi

echo "SOPS installed to ${DEST}"
sops --version
