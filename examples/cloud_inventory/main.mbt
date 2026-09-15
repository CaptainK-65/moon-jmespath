///|
fn cloud_inventory() -> Json raise {
  let input = @json.parse(
    (
      #|{"reservations":[{"instances":[{"id":"i-101","type":"compute","state":{"name":"running"}},{"id":"i-102","type":"memory","state":{"name":"stopped"}}]},{"instances":[{"id":"i-103","type":"compute","state":{"name":"running"}}]}]}
    ),
  )
  @jmespath.search(
    "reservations[].instances[?state.name == 'running'][].{id: id, type: type}",
    input,
  )
}

///|
fn main raise {
  println(cloud_inventory().stringify(indent=2))
}
