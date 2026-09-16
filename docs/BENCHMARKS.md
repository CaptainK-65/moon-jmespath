# Benchmark baseline

MoonJMES uses MoonBit's built-in benchmark harness. Run the workload on the
Wasm release backend so local and GitHub-hosted environments share the same
execution target:

```shell
moon bench --target wasm --release -p CaptainK-65/jmespath/benchmarks
```

Baseline captured on 2026-09-16 with MoonBit `0.1.20260827`:

| Workload | Mean | Samples |
| --- | ---: | ---: |
| Compile representative expression | 9.61 µs | 10 × 9,670 runs |
| Analyze compiled expression | 982.96 ns | 10 × 100,000 runs |
| Compile three-stage pipeline | 4.92 µs | 10 × 22,181 runs |
| Transform eight NDJSON records | 21.66 µs | 10 × 3,656 runs |

These numbers are a diagnostic baseline, not a cross-machine performance
promise. The Actions log retains the result for every PR so changes can be
compared under a consistent runner and toolchain.
