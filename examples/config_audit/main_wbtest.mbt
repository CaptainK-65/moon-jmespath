///|
test "configuration audit combines truthiness and comparison" {
  json_inspect(try! config_audit(), content=[
    { "service": "gateway", "retries": 1 },
  ])
}
