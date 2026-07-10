#!/usr/bin/env bash
# Serve packaged charts as a helm repo on :8879 (remote charts → ChartPath empty → lock applies).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="${ROOT}/.repo"
PORT="${PORT:-8879}"

if [[ ! -f "${REPO_DIR}/index.yaml" ]]; then
  echo "missing ${REPO_DIR}/index.yaml — run ./scripts/generate.sh first" >&2
  exit 1
fi

cd "${REPO_DIR}"
exec python3 -m http.server "${PORT}" --bind 127.0.0.1
