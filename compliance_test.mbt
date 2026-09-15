///|
/// These cases are adapted from the MIT-licensed jmespath.py compliance data.
fn compliance_case(
  given : String,
  expression : String,
  expected : String,
) -> Unit raise {
  let input = try! @json.parse(given)
  let wanted = try! @json.parse(expected)
  let actual = search(expression, input)
  if actual != wanted {
    fail(
      "compliance mismatch for \{expression}: expected \{wanted.stringify()}, got \{actual.stringify()}",
    )
  }
}

///|
test "upstream compliance: basic field traversal" {
  let given = "{\"foo\":{\"bar\":{\"baz\":\"correct\"}}}"
  compliance_case(given, "foo", "{\"bar\":{\"baz\":\"correct\"}}")
  compliance_case(given, "foo.bar", "{\"baz\":\"correct\"}")
  compliance_case(given, "foo.bar.baz", "\"correct\"")
  compliance_case(given, "foo\n.\nbar\n.baz", "\"correct\"")
  compliance_case(given, "foo.bar.baz.bad", "null")
  compliance_case(given, "bad.morebad.morebad", "null")
}

///|
test "upstream compliance: quoted identifiers and indices" {
  let given = "{\"foo\":{\"1\":[\"one\",\"two\",\"three\"],\"-1\":\"bar\"}}"
  compliance_case(given, "foo.\"1\"", "[\"one\",\"two\",\"three\"]")
  compliance_case(given, "foo.\"1\"[0]", "\"one\"")
  compliance_case(given, "foo.\"-1\"", "\"bar\"")
}

///|
test "upstream compliance: numeric filters" {
  let given = "{\"foo\":[{\"age\":20},{\"age\":25},{\"age\":30}]}"
  compliance_case(given, "foo[?age > `25`]", "[{\"age\":30}]")
  compliance_case(given, "foo[?age >= `25`]", "[{\"age\":25},{\"age\":30}]")
  compliance_case(given, "foo[?age < `25`]", "[{\"age\":20}]")
  compliance_case(given, "foo[?age <= `25`]", "[{\"age\":20},{\"age\":25}]")
  compliance_case(given, "foo[?age == `20`]", "[{\"age\":20}]")
  compliance_case(given, "foo[?age != `20`]", "[{\"age\":25},{\"age\":30}]")
}

///|
test "upstream compliance: expression and JSON value filters" {
  let given = "{\"foo\":[{\"first\":\"foo\",\"last\":\"bar\"},{\"first\":\"foo\",\"last\":\"foo\"},{\"first\":\"foo\",\"last\":\"baz\"}]}"
  compliance_case(
    given, "foo[?first == last]", "[{\"first\":\"foo\",\"last\":\"foo\"}]",
  )
  compliance_case(given, "foo[?first == last].first", "[\"foo\"]")
  let nested = "{\"foo\":[{\"top\":{\"first\":\"foo\",\"last\":\"bar\"}},{\"top\":{\"first\":\"foo\",\"last\":\"foo\"}}]}"
  compliance_case(
    nested, "foo[?top == `{\"first\": \"foo\", \"last\": \"bar\"}`]", "[{\"top\":{\"first\":\"foo\",\"last\":\"bar\"}}]",
  )
}

///|
test "upstream compliance: standard functions" {
  compliance_case("{\"foo\":[1,2,3,4]}", "sum(foo)", "10")
  compliance_case("{\"foo\":[1,2,3,4]}", "avg(foo)", "2.5")
  compliance_case("{\"foo\":\"bar\"}", "contains(foo, 'a')", "true")
  compliance_case("{\"foo\":\"bar\"}", "length(foo)", "3")
  compliance_case("{\"foo\":[3,1,2]}", "sort(foo)", "[1,2,3]")
}
