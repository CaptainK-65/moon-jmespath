///|
test "parser preserves projection chains" {
  let expression = try! compile("reservations[].instances[].state.name")
  assert_eq(expression.source(), "reservations[].instances[].state.name")
  assert_true(expression.ast is Projection(_, _))
}

///|
test "parser accepts filters, comparisons and multi-select objects" {
  let expression = try! compile("people[?age >= `18`].{name: name, age: age}")
  assert_true(expression.ast is Projection(_, _))
}

///|
test "parser accepts functions, pipes and expression references" {
  try compile("sort_by(items, &price)[*].name | [0:3]") catch {
    JmesError::Fault(_, message, offset) =>
      fail("unexpected parser error at \{offset}: \{message}")
  } noraise {
    expression => assert_true(expression.ast is PipeExpr(_, _))
  }
}

///|
test "parser rejects incomplete expressions" {
  try compile("people[?age > ]") catch {
    JmesError::Fault(kind, _, offset) => {
      assert_eq(kind, Syntax)
      assert_true(offset > 0)
    }
  } noraise {
    _ => fail("expected a syntax error")
  }
}
