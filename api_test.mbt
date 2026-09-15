///|
test "default resource limits are finite and positive" {
  let limits = Limits::default()
  assert_true(limits.max_expression_length > 0)
  assert_true(limits.max_ast_nodes > 0)
  assert_true(limits.max_depth > 0)
  assert_true(limits.max_steps > 0)
}
