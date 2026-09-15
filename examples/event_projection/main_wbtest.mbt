///|
test "event projection filters and reshapes records" {
  json_inspect(try! event_projection(), content=[
    { "at": "10:01", "message": "timeout" },
    { "at": "10:02", "message": "retry failed" },
  ])
}
