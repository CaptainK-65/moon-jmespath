# JMESPath compliance corpus

This directory vendors the JSON compliance fixtures distributed with
[`jmespath.py`](https://github.com/jmespath/jmespath.py/tree/develop/tests/compliance).
They are used unchanged under that project's MIT license; see
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

The checked-in `generated_compliance_data_test.mbt` file embeds these fixtures
so the same tests run on every MoonBit backend without filesystem access.
Regenerate it from the repository root with:

```console
moon run tools/generate_compliance.mbtx compliance/fixtures generated_compliance_data_test.mbt
moon fmt
```

The generator has a fixed manifest. Adding or removing a fixture therefore
requires an explicit source change and review.
