///|
test "bench compile representative expression" (b : @bench.T) {
  let source = "people[?active && score >= `80`].{name: name, score: score} | sort_by(@, &score)"
  b.bench(fn() { b.keep(try! compile(source)) })
}

///|
test "bench expression analysis" (b : @bench.T) {
  let expression = try! compile(
    "people[?active && score >= `80`].{name: name, tags: tags}",
  )
  b.bench(fn() {
    let analysis = expression.analyze()
    b.keep(analysis.stats.nodes + analysis.fields.length())
  })
}

///|
test "bench compile transformation pipeline" (b : @bench.T) {
  let stages = [
    "people[?active]", "[].{name: name, score: score}", "sort_by(@, &score)",
  ]
  b.bench(fn() { b.keep((try! compile_pipeline(stages)).stats().total_nodes) })
}

///|
test "bench NDJSON batch" (b : @bench.T) {
  let input =
    #|{"name":"Ada","score":96}
    #|{"name":"Lin","score":91}
    #|{"name":"Moon","score":84}
    #|{"name":"Kai","score":72}
    #|{"name":"Iris","score":88}
    #|{"name":"Ren","score":79}
    #|{"name":"Sam","score":93}
    #|{"name":"Tao","score":86}
  b.bench(fn() {
    b.keep(
      (try! search_ndjson("{name: name, passed: score >= `80`}", input)).succeeded,
    )
  })
}
