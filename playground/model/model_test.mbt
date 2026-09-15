///|
test "playground response includes result, plan, and trace" {
  let response = try! @json.parse(
    run(
      "people[?age >= `18`].name", "{\"people\":[{\"name\":\"Ada\",\"age\":36},{\"name\":\"Lin\",\"age\":15}]}",
    ),
  )
  guard response is Json::Object(document) else { fail("expected response") }
  assert_eq(document.get("ok"), Some(Json::boolean(true)))
  assert_eq(document.get("result"), Some(try! @json.parse("[\"Ada\"]")))
  assert_true(document.get("plan") is Some(Json::Object(_)))
  assert_true(document.get("trace") is Some(Json::Object(_)))
}

///|
test "playground response isolates JSON input diagnostics" {
  let response = try! @json.parse(run("foo", "{"))
  guard response is Json::Object(document) else { fail("expected response") }
  assert_eq(document.get("ok"), Some(Json::boolean(false)))
  assert_eq(document.get("stage"), Some(Json::string("input")))
  assert_eq(document.get("diagnostic"), Some(Json::null()))
}

///|
test "playground response includes source-aware query diagnostics" {
  let response = try! @json.parse(run("people.[", "{}"))
  guard response is Json::Object(document) else { fail("expected response") }
  assert_eq(document.get("ok"), Some(Json::boolean(false)))
  assert_eq(document.get("stage"), Some(Json::string("query")))
  guard document.get("diagnostic") is Some(Json::Object(diagnostic)) else {
    fail("expected query diagnostic")
  }
  assert_eq(diagnostic.get("kind"), Some(Json::string("syntax")))
}
