///|
fn parse_json_for_test(source : String) -> Json {
  try! @json.parse(source)
}

///|
test "search evaluates fields, indices and negative indices" {
  let input = parse_json_for_test(
    (
      #|{"people":[{"name":"Ada"},{"name":"Moon"}]}
    ),
  )
  json_inspect(try! search("people[0].name", input), content="Ada")
  json_inspect(try! search("people[-1].name", input), content="Moon")
}

///|
test "search evaluates flattening and chained projections" {
  let input = parse_json_for_test(
    (
      #|{"reservations":[{"instances":[{"state":{"name":"running"}},{"state":{"name":"stopped"}}]},{"instances":[{"state":{"name":"pending"}}]}]}
    ),
  )
  json_inspect(try! search("reservations[].instances[].state.name", input), content=[
    "running", "stopped", "pending",
  ])
}

///|
test "search evaluates filters and comparisons" {
  let input = parse_json_for_test(
    (
      #|{"people":[{"name":"Ada","age":36},{"name":"Lin","age":15},{"name":"Moon","age":20}]}
    ),
  )
  json_inspect(try! search("people[?age >= `18`].name", input), content=[
    "Ada", "Moon",
  ])
}

///|
test "search evaluates slices, pipes and multi-select objects" {
  let input = parse_json_for_test(
    (
      #|{"items":[{"id":"a","price":4},{"id":"b","price":8},{"id":"c","price":12}]}
    ),
  )
  json_inspect(try! search("items[0:2].{key: id, cost: price}", input), content=[
    { "key": "a", "cost": 4 },
    { "key": "b", "cost": 8 },
  ])
  json_inspect(try! search("items[*].id | [::-1]", input), content=[
    "c", "b", "a",
  ])
}
