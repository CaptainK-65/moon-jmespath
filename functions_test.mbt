///|
test "numeric and collection functions follow JMESPath semantics" {
  let input = parse_json_for_test(
    (
      #|{"values":[3,1,2],"empty":[],"label":"moonbit"}
    ),
  )
  json_inspect(try! search("sum(values)", input), content=6)
  json_inspect(try! search("avg(values)", input), content=2)
  json_inspect(try! search("sort(values)", input), content=[1, 2, 3])
  json_inspect(try! search("avg(empty)", input), content=null)
  json_inspect(try! search("length(label)", input), content=7)
}

///|
test "string, conversion and object functions are reusable" {
  let input = parse_json_for_test(
    (
      #|{"prefix":"moon","name":"moonbit","left":{"a":1},"right":{"b":2}}
    ),
  )
  json_inspect(try! search("starts_with(name, prefix)", input), content=true)
  json_inspect(try! search("contains(name, 'bit')", input), content=true)
  json_inspect(try! search("merge(left, right)", input), content={
    "a": 1,
    "b": 2,
  })
  json_inspect(try! search("to_number('42')", input), content=42)
  json_inspect(try! search("type(left)", input), content="object")
}

///|
test "expression-reference functions evaluate against each element" {
  let input = parse_json_for_test(
    (
      #|{"items":[{"name":"slow","price":9},{"name":"fast","price":2},{"name":"mid","price":5}]}
    ),
  )
  json_inspect(try! search("sort_by(items, &price)[*].name", input), content=[
    "fast", "mid", "slow",
  ])
  json_inspect(try! search("map(&name, items)", input), content=[
    "slow", "fast", "mid",
  ])
  json_inspect(try! search("min_by(items, &price).name", input), content="fast")
}

///|
test "function errors distinguish arity, type and unknown names" {
  let input = parse_json_for_test("{\"value\":1}")
  try search("length()", input) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, InvalidArity)
  } noraise {
    _ => fail("expected invalid arity")
  }
  try search("length(value)", input) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, InvalidType)
  } noraise {
    _ => fail("expected invalid type")
  }
  try search("missing(value)", input) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, UnknownFunction)
  } noraise {
    _ => fail("expected unknown function")
  }
}
