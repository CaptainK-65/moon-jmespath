# MoonJMES

[![CI](https://github.com/CaptainK-65/moon-jmespath/actions/workflows/ci.yml/badge.svg)](https://github.com/CaptainK-65/moon-jmespath/actions/workflows/ci.yml)
[![Pages](https://github.com/CaptainK-65/moon-jmespath/actions/workflows/pages.yml/badge.svg)](https://github.com/CaptainK-65/moon-jmespath/actions/workflows/pages.yml)

MoonJMES is a reusable JMESPath 1.0 query toolkit written in MoonBit. It
provides a portable core library, an extensible cached engine, data-processing
utilities, diagnostics, and a static visual Playground without coupling the
library to a product-specific data model.

Try the [MoonJMES Playground](https://captaink-65.github.io/moon-jmespath/) or
use the library on the Wasm, Wasm GC, JavaScript, and Native backends.

## Quick start

After publication to mooncakes.io, add the package with:

```shell
moon add CaptainK-65/jmespath
```

Compile once and evaluate repeatedly:

```mbt check
///|
test "query JSON with a reusable expression" {
  let input = try! @json.parse(
    "{\"people\":[{\"name\":\"Ada\",\"age\":36},{\"name\":\"Lin\",\"age\":15}]}",
  )
  let expression = try! @jmespath.compile("people[?age >= `18`].name")
  json_inspect(try! expression.search(input), content=["Ada"])
}
```

All public failures are catchable `JmesError` values. `Limits` independently
bounds expression length, AST size, evaluation depth, and evaluation steps.

## Reusable library surface

- JMESPath traversal, slicing, wildcards, flattening, projections, filters,
  comparisons, boolean expressions, pipes, expression references, multi-select
  expressions, and the standard function set.
- `Engine` with bounded LRU compilation caching, custom-function registration,
  isolated batch results, runtime statistics, and trace evaluation.
- Opaque compiled expressions and pipelines, structured diagnostics with source
  spans, JSON AST export, query plans, static analysis, and bounded traces.
- Compile-once NDJSON processing, named query catalogs, and multi-stage query
  pipelines with intermediate results.
- Full attributed `jmespath.py` fixture corpus: 908 generated compliance cases
  across 16 fixture files, with no allowlist or expected failures.
- A browser Playground that displays results, diagnostics, query-plan metrics,
  AST structure, and a step-by-step trace.

## Engine example

```mbt check
///|
test "reuse an engine cache" {
  let engine = try! @jmespath.Engine::new(cache_capacity=64)
  let input = try! @json.parse("{\"values\":[3,1,2]}")
  json_inspect(try! engine.search("sort(values)", input), content=[1, 2, 3])
  inspect(engine.stats().cache_hits, content="0")
  ignore(try! engine.search("sort(values)", input))
  inspect(engine.stats().cache_hits, content="1")
}
```

## CLI and scenarios

```shell
moon run cmd/moonjmes -- 'people[*].name' '{"people":[{"name":"Ada"},{"name":"Moon"}]}'
moon run examples/cloud_inventory
moon run examples/config_audit
moon run examples/event_projection
```

## Verification

```shell
moon update
moon fmt --check
moon run tools/check_source_gate.mbtx -- 3500
moon check --target all --deny-warn
moon test --target all --deny-warn
moon coverage analyze -p CaptainK-65/jmespath -- -f summary
moon bench --target wasm --release -p CaptainK-65/jmespath/benchmarks
moon build --target all --release
moon package
```

CI additionally validates the 908-case corpus explicitly, the JavaScript
export contract, a real headless-browser execution, and the assembled Pages
artifact. Generated JavaScript and static bundles remain untracked.

See [architecture](docs/ARCHITECTURE.md), [compliance](docs/COMPLIANCE.md),
[benchmarks](docs/BENCHMARKS.md), and [release evidence](docs/RELEASE_EVIDENCE.md)
for reproducible details.

## License

MoonJMES is Apache-2.0 licensed. The MIT-licensed compliance data is attributed
in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
