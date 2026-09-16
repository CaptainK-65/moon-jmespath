# Compliance testing

MoonJMES runs all 908 cases from the 16 MIT-licensed compliance fixture files
distributed with `jmespath.py`. The corpus covers valid results and invalid
expression behavior for basic expressions, benchmarks, booleans, current-node
expressions, escaping, filters, functions, identifiers, indices, literals,
multi-select expressions, pipes, slices, syntax, Unicode, and wildcards.

The source and license are recorded in
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). Fixtures are stored as JSON
under `compliance/fixtures`; `tools/generate_compliance.mbtx` deterministically
generates the MoonBit test data. The generated file is not counted by the
production-source gate.

There is no allowlist, skip list, expected failure, or backend-specific semantic
exception. Run the same test suite on every supported backend with:

```shell
moon test --target all --deny-warn
```

CI also exposes the compliance boundary as a named gate:

```shell
moon test full_compliance_test.mbt --target wasm --deny-warn
```

Passing the imported suite is strong interoperability evidence, while the
JMESPath specification remains the normative definition of the language.
