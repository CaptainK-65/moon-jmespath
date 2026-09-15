///|
test "CLI delegates JSON queries to the library" {
  inspect(
    try! execute(
      "people[*].name", "{\"people\":[{\"name\":\"Ada\"},{\"name\":\"Moon\"}]}",
    ),
    content="[\"Ada\",\"Moon\"]",
  )
}

///|
test "CLI exposes a reproducible usage string" {
  inspect(
    usage(),
    content="Usage: moon run cmd/moonjmes -- '<expression>' '<json>'",
  )
}
