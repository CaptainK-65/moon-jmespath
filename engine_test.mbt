///|
fn double_number(arguments : ArrayView[Json]) -> Json raise JmesError {
  match arguments[0] {
    Json::Number(value, ..) => Json::number(value * 2.0)
    _ => raise JmesError::Fault(InvalidType, "double(): expected a number", 0)
  }
}

///|
fn require_positive(arguments : ArrayView[Json]) -> Json raise JmesError {
  match arguments[0] {
    Json::Number(value, ..) =>
      if value >= 0.0 {
        Json::number(value)
      } else {
        raise JmesError::Fault(
          InvalidValue,
          "positive(): value must not be negative",
          0,
        )
      }
    _ => raise JmesError::Fault(InvalidType, "positive(): expected a number", 0)
  }
}

///|
test "engine caches compiled expressions with bounded LRU eviction" {
  let engine = try! Engine::new(cache_capacity=2)
  let input = try! @json.parse("{\"a\":1,\"b\":2,\"c\":3}")
  json_inspect(try! engine.search("a", input), content=1)
  json_inspect(try! engine.search("a", input), content=1)
  json_inspect(try! engine.search("b", input), content=2)
  json_inspect(try! engine.search("c", input), content=3)
  json_inspect(try! engine.search("a", input), content=1)
  let stats = engine.stats()
  assert_eq(stats.cache_entries, 2)
  assert_eq(stats.cache_hits, 1)
  assert_eq(stats.cache_misses, 4)
  assert_eq(stats.custom_functions, 0)
  engine.clear_cache()
  assert_eq(engine.stats().cache_entries, 0)
}

///|
test "engine evaluates registered custom functions" {
  let engine = try! Engine::new()
  engine.register_function("double", 1, Some(1), double_number)
  let input = try! @json.parse("{\"values\":[1,2,3]}")
  json_inspect(try! engine.search("values[].double(@)", input), content=[
    2, 4, 6,
  ])
  assert_eq(engine.stats().custom_functions, 1)
  engine.unregister_function("double")
  try engine.search("double(`1`)", input) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, UnknownFunction)
  } noraise {
    _ => fail("expected an unknown-function error")
  }
}

///|
test "engine rejects invalid registrations and custom arity" {
  let engine = try! Engine::new()
  engine.register_function("sort", 1, Some(1), double_number) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, InvalidValue)
  }
  engine.register_function("bad-name", 1, Some(1), double_number) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, InvalidValue)
  }
  engine.register_function("double", 1, Some(1), double_number)
  try engine.search("double()", Json::null()) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, InvalidArity)
  } noraise {
    _ => fail("expected an invalid-arity error")
  }
}

///|
test "batch search isolates evaluation failures by input index" {
  let engine = try! Engine::new()
  engine.register_function("positive", 1, Some(1), require_positive)
  let inputs = [
    try! @json.parse("{\"value\":1}"),
    try! @json.parse("{\"value\":-1}"),
    try! @json.parse("{\"value\":2}"),
  ]
  let results = try! engine.search_batch("positive(value)", inputs[:])
  assert_eq(results.length(), 3)
  guard results[0] is Value(first) else { fail("expected first value") }
  json_inspect(first, content=1)
  guard results[1] is Failure(index, diagnostic) else {
    fail("expected isolated failure")
  }
  assert_eq(index, 1)
  assert_eq(diagnostic.kind, InvalidValue)
  guard results[2] is Value(last) else { fail("expected last value") }
  json_inspect(last, content=2)
}

///|
test "engine validates cache capacity" {
  try Engine::new(cache_capacity=-1) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, InvalidValue)
  } noraise {
    _ => fail("expected an invalid cache capacity error")
  }
}
