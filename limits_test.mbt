///|
fn assert_limit_error(thunk : () -> Unit raise JmesError) -> Unit raise {
  try thunk() catch {
    JmesError::Fault(kind, message, _) => {
      assert_eq(kind, LimitExceeded)
      assert_true(message.contains("limit exceeded"))
    }
  } noraise {
    _ => fail("expected a limit error")
  }
}

///|
test "compile enforces source length and AST node limits" {
  let source_limit : Limits = {
    max_expression_length: 3,
    max_ast_nodes: 100,
    max_depth: 100,
    max_steps: 100,
  }
  assert_limit_error(() => ignore(compile("abcd", limits=source_limit)))
  let node_limit : Limits = {
    max_expression_length: 100,
    max_ast_nodes: 2,
    max_depth: 100,
    max_steps: 100,
  }
  assert_limit_error(() => ignore(compile("a.b.c", limits=node_limit)))
}

///|
test "evaluation enforces depth and step limits" {
  let depth_limit : Limits = {
    max_expression_length: 100,
    max_ast_nodes: 100,
    max_depth: 1,
    max_steps: 100,
  }
  let nested = try! compile("a.b.c", limits=depth_limit)
  assert_limit_error(() => {
    ignore(nested.search(parse_json_for_test("{\"a\":{\"b\":{\"c\":1}}}")))
  })
  let step_limit : Limits = {
    max_expression_length: 100,
    max_ast_nodes: 100,
    max_depth: 100,
    max_steps: 2,
  }
  let projected = try! compile("items[*].name", limits=step_limit)
  assert_limit_error(() => {
    ignore(
      projected.search(parse_json_for_test("{\"items\":[{\"name\":\"a\"}]}")),
    )
  })
}
