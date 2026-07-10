#!/usr/bin/env bash
# Generate a helmfile with N releases of the SAME remote chart.
# Same chart+version → v1.7 withChartOperationLock serializes DiffRelease (#2662).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COUNT="${1:-40}"
MODE="${2:-same}" # same | unique
OUT="${ROOT}/helmfile.yaml"
REPO_DIR="${ROOT}/.repo"
CHART_SRC="${ROOT}/charts/slowpoke"

rm -rf "${REPO_DIR}"
mkdir -p "${REPO_DIR}"

if [[ "${MODE}" == "same" ]]; then
  helm package "${CHART_SRC}" -d "${REPO_DIR}" >/dev/null
else
  for i in $(seq 1 "${COUNT}"); do
    tmp="$(mktemp -d)"
    cp -R "${CHART_SRC}/." "${tmp}/"
    # Unique chart name → different lock keys → stays parallel in v1.7
    sed -i.bak "s/^name: slowpoke$/name: slowpoke-${i}/" "${tmp}/Chart.yaml"
    rm -f "${tmp}/Chart.yaml.bak"
    helm package "${tmp}" -d "${REPO_DIR}" >/dev/null
    rm -rf "${tmp}"
  done
fi

helm repo index "${REPO_DIR}"

{
  echo "# Generated: ${COUNT} releases, mode=${MODE}"
  echo "# Do not edit; run: ./scripts/generate.sh ${COUNT} ${MODE}"
  echo "repositories:"
  echo "  - name: local"
  echo "    url: http://127.0.0.1:8879/"
  echo
  echo "releases:"
  for i in $(seq 1 "${COUNT}"); do
    if [[ "${MODE}" == "same" ]]; then
      chart="local/slowpoke"
    else
      chart="local/slowpoke-${i}"
    fi
    cat <<EOF
  - name: app-${i}
    namespace: default
    chart: ${chart}
    version: 0.1.0
    values:
      - config: "release-${i}"
EOF
  done
} > "${OUT}"

echo "Wrote ${OUT} (${COUNT} releases, mode=${MODE})"
echo "Repo packages in ${REPO_DIR}"
