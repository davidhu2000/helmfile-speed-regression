# helmfile 1.6 → 1.7 diff speed repro

Repro for regression from [helmfile#2662](https://github.com/helmfile/helmfile/pull/2662) (`withChartOperationLock`): same remote chart+version → `DiffRelease` / `SyncRelease` fully serialized in **v1.7.0**.

## Measured locally (kind, 40 releases, concurrency=0)

| mode | v1.6.0 | v1.7.0 |
|------|--------|--------|
| `same` (one remote chart) | 2.34s | **11.89s** (~5×) |
| `unique` (40 charts) | 2.53s | 2.18s |

Heavier charts → larger ratio (serialize whole helm op, not just download).

## What it does

1. Packages tiny chart into **local HTTP helm repo** (remote → `ChartPath == ""` → lock applies).
2. Generates N releases all pointing at **same** `local/slowpoke`.
3. Times `helmfile diff` on **v1.6.0** vs **v1.7.0** against kind.

Control `unique`: N different chart names → no lock contention → times similar.

## Local

Needs: `helm` (+ `helm-diff` plugin), `kubectl`, `python3`, `curl`, kind/cluster.

```bash
./scripts/install-helmfiles.sh
export PATH="$PWD/bin:$PATH"
helm plugin install https://github.com/databus23/helm-diff   # once

kind create cluster --name helmfile-speed
kubectl config use-context kind-helmfile-speed

COUNT=40 MODE=same CONCURRENCY=0 ./scripts/bench.sh
COUNT=40 MODE=unique CONCURRENCY=0 ./scripts/bench.sh   # control
```

## GitHub Actions

`.github/workflows/bench.yml` — kind + both helmfiles + bench. `workflow_dispatch` inputs: `count` / `mode` / `concurrency`.

## Why remote + same chart

From #2662:

- Lock key = `chart + version`
- Skipped when `release.ChartPath != ""` (local / pre-fetched)
- Entire helm op serialized, not just download

Local charts alone will **not** show this regression.
