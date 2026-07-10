#!/usr/bin/env bash
# Bench helmfile diff: v1.6.0 vs v1.7.0, N releases of the same remote chart (#2662).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COUNT="${COUNT:-40}"
BIN="${ROOT}/bin"
REPO="${ROOT}/.repo"
export PATH="${BIN}:${PATH}"

need() { command -v "$1" >/dev/null || { echo "need $1" >&2; exit 1; }; }
need helm; need kubectl; need curl; need python3

# --- install helmfile binaries if missing ---
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"; case "$arch" in x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; esac
mkdir -p "${BIN}"
for ver in 1.6.0 1.7.0; do
  out="helmfile-${ver%.*}" # helmfile-1.6 / helmfile-1.7
  [[ -x "${BIN}/${out}" ]] && continue
  url="https://github.com/helmfile/helmfile/releases/download/v${ver}/helmfile_${ver}_${os}_${arch}.tar.gz"
  echo "download ${url}"
  tmp="$(mktemp -d)"
  curl -fsSL "${url}" | tar -xz -C "${tmp}"
  mv "${tmp}/helmfile" "${BIN}/${out}"
  rm -rf "${tmp}"
done

kubectl cluster-info >/dev/null

# --- package chart as remote helm repo ---
rm -rf "${REPO}"
mkdir -p "${REPO}"
helm package "${ROOT}/charts/slowpoke" -d "${REPO}" >/dev/null
helm repo index "${REPO}"

python3 -m http.server 8879 --bind 127.0.0.1 --directory "${REPO}" &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in $(seq 1 30); do curl -sf http://127.0.0.1:8879/index.yaml >/dev/null && break; sleep 0.2; done

export HELM_PLUGINS="${HELM_PLUGINS:-$(helm env HELM_PLUGINS)}"
helm repo add local http://127.0.0.1:8879/ --force-update >/dev/null
helm repo update local >/dev/null

# --- helmfile: N releases, same remote chart ---
{
  echo "repositories:"
  echo "  - name: local"
  echo "    url: http://127.0.0.1:8879/"
  echo "releases:"
  for i in $(seq 1 "${COUNT}"); do
    cat <<EOF
  - name: app-${i}
    namespace: default
    chart: local/slowpoke
    version: 0.2.0
    values:
      - config: "release-${i}"
EOF
  done
} > "${ROOT}/helmfile.yaml"

cd "${ROOT}"
results="${ROOT}/results.txt"
echo "count=${COUNT}" | tee "${results}"

for label_bin in "v1.6.0:helmfile-1.6" "v1.7.0:helmfile-1.7"; do
  label="${label_bin%%:*}"
  bin="${label_bin##*:}"
  echo "=== ${label} ==="
  start=$(python3 -c 'import time; print(time.time())')
  "${bin}" diff --concurrency 0 --detailed-exitcode=false >/dev/null || true
  end=$(python3 -c 'import time; print(time.time())')
  elapsed=$(python3 -c "print(round(float('$end') - float('$start'), 2))")
  echo "${label}: ${elapsed}s" | tee -a "${results}"
done

echo "---"; cat "${results}"
