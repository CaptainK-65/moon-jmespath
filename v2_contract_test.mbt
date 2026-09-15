///|
test "compiled expressions remain opaque to downstream callers" {
  let expression = @jmespath.compile("people[*].name")
  inspect(expression.source(), content="people[*].name")
}

///|
test "syntax errors convert to one-based source diagnostics" {
  let source = "people\n  .name\n  .["
  try @jmespath.compile(source) catch {
    error => {
      let diagnostic = error.diagnostic(source)
      json_inspect(diagnostic.to_json(), content={
        "kind": "syntax",
        "message": "expected a field, wildcard, or object after '.'",
        "span": { "start": 18, "end": 19, "line": 3, "column": 4 },
        "excerpt": "  .[",
      })
    }
  } noraise {
    _ => fail("expected syntax error")
  }
}

///|
test "diagnostics clamp data-only offsets to the source" {
  let error = @jmespath.JmesError::Fault(
    @jmespath.ErrorKind::InvalidType,
    "bad value",
    999,
  )
  json_inspect(error.diagnostic("a").to_json(), content={
    "kind": "invalid_type",
    "message": "bad value",
    "span": { "start": 1, "end": 1, "line": 1, "column": 2 },
    "excerpt": "a",
  })
}
