///|
fn config_audit() -> Json raise {
  let input = @json.parse(
    (
      #|{"services":[{"name":"gateway","enabled":true,"retries":1},{"name":"billing","enabled":true,"retries":5},{"name":"archive","enabled":false,"retries":0}]}
    ),
  )
  @jmespath.search(
    "services[?enabled && retries < `3`].{service: name, retries: retries}", input,
  )
}

///|
fn main raise {
  println(config_audit().stringify(indent=2))
}
