# MoonJMES

MoonJMES is a reusable [JMESPath 1.0](https://jmespath.org/specification.html)
query engine written in MoonBit. It is designed as a general-purpose ecosystem
library: applications pass a JSON value and a query expression, and receive a
JSON result without embedding product-specific rules.

> Status: active v0.1.0 development. The public API is being implemented on the
> `feat/jmespath-v0.1.0` branch.

## Planned public API

```mbt nocheck
///|
let expression = @jmespath.compile("people[?age >= `18`].name")

///|
let result = expression.search(input)
```

The first release targets the standard language constructs, built-in
functions, structured parse/evaluation errors, configurable resource limits,
cross-target CI, specification-derived tests, and a small CLI example.

## License

Apache-2.0. Third-party compliance fixtures, where used, retain their own
licenses and attribution.

