///|
test "cloud inventory selects reusable resource fields" {
  json_inspect(try! cloud_inventory(), content=[
    { "id": "i-101", "type": "compute" },
    { "id": "i-103", "type": "compute" },
  ])
}
