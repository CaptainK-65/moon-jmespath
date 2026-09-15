# MoonJMES

[![CI](https://github.com/CaptainK-65/moon-jmespath/actions/workflows/ci.yml/badge.svg)](https://github.com/CaptainK-65/moon-jmespath/actions/workflows/ci.yml)

MoonJMES is a reusable JSON query library written in MoonBit. It compiles
[JMESPath 1.0](https://jmespath.org/specification.html) expressions into an
internal AST and evaluates them against MoonBit's standard `Json` type. The
engine has no dependency on a web UI, database, or product-specific data model.

Version 0.1.0 implements the language core and standard function set. Its
conformance suite is intentionally reported as a selected, attributed subset;
full upstream-suite conformance remains future work.

## Why a library?

Applications often need to select, filter, flatten, and reshape JSON returned
by APIs or configuration files. Reimplementing those operations as ad hoc
loops couples query policy to the application. MoonJMES provides a compiled
query boundary that can be reused by command-line tools, services, tests, and
MoonBit applications on all four MoonBit backends.

## Quick start

After the package is published to mooncakes.io, add it with:

```shell
moon add CaptainK-65/jmespath
```

The public API supports one-shot search and reusable compiled expressions:

```mbt check
///|
test "query JSON with a reusable compiled expression" {
  let input = try! @json.parse(
    (
      #|{"people":[{"name":"Ada","age":36},{"name":"Lin","age":15}]}
    ),
  )
  let expression = try! @jmespath.compile("people[?age >= `18`].name")
  json_inspect(try! expression.search(input), content=["Ada"])
}
```

Every compile or evaluation failure is a catchable `JmesError::Fault` carrying
an `ErrorKind`, diagnostic message, and source offset. Optional `Limits`
protect callers from excessive expression size, AST growth, recursion depth,
and evaluation work.

## Supported v0.1.0 surface

- field and quoted-identifier access, current node, literals, and parentheses;
- array indices, positive/negative slices, wildcards, flattening, and object
  values;
- list/object projections, filter projections, multi-select lists and objects;
- pipe, comparison, boolean AND/OR/NOT, and expression references;
- standard functions: `abs`, `avg`, `contains`, `ceil`, `ends_with`, `floor`,
  `join`, `keys`, `length`, `map`, `max`, `max_by`, `merge`, `min`, `min_by`,
  `not_null`, `reverse`, `sort`, `sort_by`, `starts_with`, `sum`, `to_array`,
  `to_number`, `to_string`, `type`, and `values`;
- the `wasm`, `wasm-gc`, `js`, and `native` targets.

Current non-goals are custom function registration, streaming JSON, a web UI,
and a database adapter.

## CLI

The repository includes a deliberately thin CLI consumer:

```shell
moon run cmd/moonjmes -- 'people[*].name' '{"people":[{"name":"Ada"},{"name":"Moon"}]}'
```

Expected output:

```json
["Ada","Moon"]
```

## Reproducible scenarios

Three complete consumers demonstrate ecosystem reuse rather than a single
product flow:

```shell
moon run examples/cloud_inventory
moon run examples/config_audit
moon run examples/event_projection
```

They cover nested cloud-resource flattening, configuration policy filtering,
and event record projection. Each scenario has its own regression test.

## Development and verification

MoonBit `0.1.20260827` or newer is recommended for the current source tree.

```shell
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all --release
moon info
```

CI runs the same strict checks, a CLI smoke test, and all three examples. See
[`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) for the exact compliance-test policy
and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for fixture provenance.

## Architecture

The lexer records source offsets, the Pratt-style parser builds a
projection-aware AST, and the evaluator applies explicit resource limits while
walking standard MoonBit `Json` values. Function dispatch is isolated from
syntax parsing, so adding a function cannot silently change grammar rules. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for component boundaries.

## License

MoonJMES is licensed under Apache-2.0. Selected compliance data is available
under its upstream MIT license, reproduced in the third-party notices.

