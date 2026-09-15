# Compliance testing

MoonJMES uses contract tests derived from the JMESPath 1.0 specification and a
selected subset of the MIT-licensed `jmespath.py` compliance data. The selected
cases exercise field traversal, quoted identifiers, array indices, comparisons,
filter projections, JSON literal equality, and standard functions.

The upstream project and license are recorded in
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md). The independent
`jmespath.test` repository is not vendored because it does not currently carry
an explicit license file.

Run the suite on every supported backend:

```shell
moon test --target all
```

Coverage will expand incrementally. A passing subset is never represented as
complete JMESPath conformance; release notes report the exact tested scope.

