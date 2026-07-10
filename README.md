# helmfile 1.6 → 1.7 diff speed repro

Repro for [helmfile#2662](https://github.com/helmfile/helmfile/pull/2662): same remote chart → `DiffRelease` serialized in v1.7.

```bash
# needs: helm, helm-diff plugin, kubectl (kind ok), curl, python3
kind create cluster --name helmfile-speed   # if needed
COUNT=10 ./scripts/bench.sh
```

Reports avg seconds/release (`total / N`).

Manual run: Actions → bench → Run workflow.
