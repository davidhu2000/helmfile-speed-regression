#!/usr/bin/env bash
# Install helmfile v1.6.0 and v1.7.0 side-by-side into ./bin
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/bin"
mkdir -p "${BIN}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
esac

install_ver() {
  local ver="$1"
  local out="$2"
  local url="https://github.com/helmfile/helmfile/releases/download/v${ver}/helmfile_${ver}_${OS}_${ARCH}.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  echo "Downloading ${url}"
  curl -fsSL "${url}" | tar -xz -C "${tmp}"
  mv "${tmp}/helmfile" "${BIN}/${out}"
  chmod +x "${BIN}/${out}"
  rm -rf "${tmp}"
  "${BIN}/${out}" version
}

install_ver "1.6.0" "helmfile-1.6"
install_ver "1.7.0" "helmfile-1.7"

echo "Installed:"
ls -la "${BIN}/helmfile-1.6" "${BIN}/helmfile-1.7"
echo "Add to PATH: export PATH=\"${BIN}:\$PATH\""
