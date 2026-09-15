///|
fn trace_increment(arguments : ArrayView[Json]) -> Json raise JmesError {
  match arguments[0] {
    Json::Number(value, ..) => Json::number(value + 1.0)
    _ => raise JmesError::Fault(InvalidType, "inc(): expected a number", 0)
  }
}

///|
test "explain returns stable JSON without exposing AST constructors" {
  let expression = try! compile("people[?age >= `18`].{name: name}")
  let plan = expression.explain()
  assert_eq(plan.source, expression.source())
  assert_true(plan.stats.nodes >= 8)
  assert_true(plan.stats.max_depth >= 3)
  assert_true(plan.stats.projections >= 1)
  assert_true(plan.stats.fields >= 3)
  guard plan.ast is Json::Object(ast) else { fail("expected object AST") }
  assert_eq(ast.get("type"), Some(Json::string("projection")))
  guard plan.to_json() is Json::Object(document) else {
    fail("expected plan JSON")
  }
  assert_eq(document.get("source"), Some(Json::string(expression.source())))
}

///|
test "trace records post-order evaluation with result types" {
  let input = try! @json.parse(
    "{\"people\":[{\"name\":\"Ada\"},{\"name\":\"Lin\"}]}",
  )
  let expression = try! compile("people[*].name")
  let report = try! expression.trace(input)
  json_inspect(report.result, content=["Ada", "Lin"])
  assert_eq(report.total_steps, report.events.length())
  assert_true(!report.truncated)
  assert_true(report.events.length() > 3)
  let final_event = report.events[report.events.length() - 1]
  assert_eq(final_event.operation, "sequence")
  assert_eq(final_event.input_type, "object")
  assert_eq(final_event.output_type, "array")
}

///|
test "trace bounds events and previews independently" {
  let expression = try! compile("items[*]")
  let input = try! @json.parse("{\"items\":[\"abcdefgh\",\"ijklmnop\"]}")
  let report = try! expression.trace(input, options={
    max_events: 2,
    preview_characters: 4,
  })
  assert_eq(report.events.length(), 2)
  assert_true(report.total_steps > report.events.length())
  assert_true(report.truncated)
  for event in report.events {
    assert_true(event.output_preview.length() <= 5)
  }
}

///|
test "engine trace includes registered custom functions" {
  let engine = try! Engine::new()
  engine.register_function("inc", 1, Some(1), trace_increment)
  let input = try! @json.parse("{\"value\":4}")
  let report = try! engine.trace("inc(value)", input)
  json_inspect(report.result, content=5)
  assert_true(report.events.any(event => event.operation == "function"))
  guard report.to_json() is Json::Object(document) else {
    fail("expected trace JSON")
  }
  assert_eq(
    document.get("total_steps"),
    Some(Json::number(report.total_steps.to_double())),
  )
}
