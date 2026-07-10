#!/usr/bin/env bash
# Time helmfile diff on v1.6.0 vs v1.7.0 against the same generated helmfile.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COUNT="${COUNT:-40}"
MODE="${MODE:-same}"
CONCURRENCY="${CONCURRENCY:-0}"
HELMFILE_1_6="${HELMFILE_1_6:-helmfile-1.6}"
HELMFILE_1_7="${HELMFILE_1_7:-helmfile-1.7}"
RESULTS="${ROOT}/results.txt"

cd "${ROOT}"

need() { command -v "$1" >/dev/null || { echo "need $1" >&2; exit 1; }; }
need helm
need kubectl
need python3
need "${HELMFILE_1_6}"
need "${HELMFILE_1_7}"

kubectl cluster-info >/dev/null

./scripts/generate.sh "${COUNT}" "${MODE}"

# Isolate chart cache only — keep real HELM_DATA_HOME so helm-diff plugin stays visible.
HELM_CACHE="$(mktemp -d)"
export HELM_CACHE_HOME="${HELM_CACHE}"
# Capture plugins path before any env mutation (helm 4 reads HELM_PLUGINS / data home).
export HELM_PLUGINS="${HELM_PLUGINS:-$(helm env HELM_PLUGINS)}"

# Kill leftover server from prior run
if [[ -f "${ROOT}/.repo-server.pid" ]]; then
  kill "$(cat "${ROOT}/.repo-server.pid")" 2>/dev/null || true
  rm -f "${ROOT}/.repo-server.pid"
fi

./scripts/serve-repo.sh &
echo $! > "${ROOT}/.repo-server.pid"
trap 'kill "$(cat "${ROOT}/.repo-server.pid")" 2>/dev/null || true; rm -f "${ROOT}/.repo-server.pid"; rm -rf "${HELM_CACHE}"' EXIT

# Wait for repo
for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:8879/index.yaml" >/dev/null && break
  sleep 0.2
done
curl -sf "http://127.0.0.1:8879/index.yaml" >/dev/null

helm repo add local "http://127.0.0.1:8879/" --force-update
helm repo update local

run_one() {
  local bin="$1"
  local label="$2"
  # Diff against empty cluster (no releases installed) — still exercises DiffRelease + lock.
  echo "=== ${label} ($(command -v "${bin}")) ==="
  local start end elapsed
  start=$(python3 -c 'import time; print(time.time())')
  # concurrency 0 = unlimited in helmfile
  "${bin}" diff --concurrency "${CONCURRENCY}" --detailed-exitcode=false >/dev/null || true
  end=$(python3 -c 'import time; print(time.time())')
  elapsed=$(python3 -c "print(round(float('$end') - float('$start'), 2))")
  echo "${label}: ${elapsed}s"
  echo "${label}: ${elapsed}s" >> "${RESULTS}"
}

: > "${RESULTS}"
{
  echo "count=${COUNT} mode=${MODE} concurrency=${CONCURRENCY}"
  echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "helm=$(helm version --short 2>/dev/null || helm version)"
} | tee "${RESULTS}"

run_one "${HELMFILE_1_6}" "v1.6.0"
run_one "${HELMFILE_1_7}" "v1.7.0"

echo
echo "--- results ---"
cat "${RESULTS}"
