///|
fn event_projection() -> Json raise {
  let input = @json.parse(
    (
      #|{"events":[{"timestamp":"10:00","severity":"info","message":"started"},{"timestamp":"10:01","severity":"error","message":"timeout"},{"timestamp":"10:02","severity":"error","message":"retry failed"}]}
    ),
  )
  @jmespath.search(
    "events[?severity == 'error'].{at: timestamp, message: message}", input,
  )
}

///|
fn main raise {
  println(event_projection().stringify(indent=2))
}
