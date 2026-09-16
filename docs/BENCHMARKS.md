# Benchmark baseline

MoonJMES uses MoonBit's built-in benchmark harness. Run the workload on the
Wasm release backend so local and GitHub-hosted environments share the same
execution target:

```shell
moon bench --target wasm --release -p CaptainK-65/jmespath
```

Baseline captured on 2026-09-15 with MoonBit `0.1.20260827`:

| Workload | Mean | Samples |
| --- | ---: | ---: |
| Compile representative expression | 9.59 µs | 10 × 11,899 runs |
| Analyze compiled expression | 885.60 ns | 10 × 85,274 runs |
| Compile three-stage pipeline | 6.90 µs | 10 × 24,766 runs |
| Transform eight NDJSON records | 21.90 µs | 10 × 3,525 runs |

These numbers are a diagnostic baseline, not a cross-machine performance
promise. The Actions log retains the result for every PR so changes can be
compared under a consistent runner and toolchain.
