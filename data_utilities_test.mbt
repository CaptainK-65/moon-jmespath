///|
fn add_ten(arguments : ArrayView[Json]) -> Json raise JmesError {
  match arguments[0] {
    Json::Number(value, ..) => Json::number(value + 10.0)
    _ => raise JmesError::Fault(InvalidType, "add_ten(): number required", 0)
  }
}

///|
test "static analysis inventories fields, functions, and portability" {
  let expression = try! compile(
    "items[?active].{name: name, score: custom_score(score)}",
  )
  let analysis = expression.analyze()
  assert_eq(analysis.fields, ["active", "items", "name", "score"])
  assert_eq(analysis.functions, ["custom_score"])
  assert_true(analysis.uses_filters)
  assert_true(
    analysis.findings.any(finding => finding.code == "custom_function"),
  )
  guard analysis.to_json() is Json::Object(document) else {
    fail("expected analysis JSON")
  }
  assert_eq(document.get("uses_filters"), Some(Json::boolean(true)))
}

///|
test "static analysis applies caller-defined complexity thresholds" {
  let expression = try! compile("a.b.c[*].d[*].e")
  let analysis = expression.analyze(options={
    node_warning_threshold: 1,
    depth_warning_threshold: 1,
    projection_warning_threshold: 1,
  })
  assert_true(
    analysis.findings.any(finding => finding.code == "high_node_count"),
  )
  assert_true(
    analysis.findings.any(finding => finding.code == "high_nesting_depth"),
  )
  assert_true(
    analysis.findings.any(finding => finding.code == "projection_heavy"),
  )
}

///|
test "compiled pipeline returns ordered intermediate values" {
  let sources = ["people", "[?active]", "[].name"]
  let pipeline = try! compile_pipeline(sources[:])
  let input = try! @json.parse(
    "{\"people\":[{\"name\":\"Ada\",\"active\":true},{\"name\":\"Lin\",\"active\":false},{\"name\":\"Moon\",\"active\":true}]}",
  )
  let report = try! pipeline.search(input)
  json_inspect(report.result, content=["Ada", "Moon"])
  assert_eq(report.intermediate.length(), 3)
  assert_eq(pipeline.sources(), sources)
  assert_eq(pipeline.stats().stages, 3)
  assert_eq(pipeline.explain().length(), 3)
  guard report.to_json() is Json::Object(_) else {
    fail("expected pipeline report JSON")
  }
}

///|
test "engine pipeline uses cache and custom functions" {
  let engine = try! Engine::new()
  engine.register_function("add_ten", 1, Some(1), add_ten)
  let sources = ["value", "add_ten(@)"]
  let pipeline = try! engine.compile_pipeline(sources[:])
  let report = try! engine.search_pipeline(
    pipeline,
    try! @json.parse("{\"value\":5}"),
  )
  json_inspect(report.result, content=15)
  assert_eq(engine.stats().cache_entries, 2)
}

///|
test "empty pipeline is rejected" {
  let sources : Array[String] = []
  try compile_pipeline(sources[:]) catch {
    JmesError::Fault(kind, _, _) => assert_eq(kind, InvalidValue)
  } noraise {
    _ => fail("expected empty pipeline error")
  }
}

///|
test "NDJSON processing reports line-level parse failures" {
  let document = "{\"name\":\"Ada\"}\nnot-json\n\n{\"name\":\"Moon\"}\n"
  let report = try! search_ndjson("name", document)
  assert_eq(report.processed, 3)
  assert_eq(report.succeeded, 2)
  assert_eq(report.failed, 1)
  assert_true(!report.stopped_early)
  guard report.items[1] is Rejected(failure) else {
    fail("expected rejected line")
  }
  assert_eq(failure.line, 2)
  assert_eq(failure.stage, "input")
  guard report.to_json() is Json::Object(_) else {
    fail("expected NDJSON report JSON")
  }
}

///|
test "NDJSON processing can stop after a query failure" {
  let document = "{\"value\":[1,2]}\n{\"value\":1}\n{\"value\":[3]}"
  let report = try! search_ndjson("length(value)", document, options={
    skip_blank_lines: true,
    continue_on_error: false,
    include_input: true,
  })
  assert_eq(report.processed, 2)
  assert_eq(report.succeeded, 1)
  assert_eq(report.failed, 1)
  assert_true(report.stopped_early)
  guard report.items[0] is Record(record) else { fail("expected record") }
  assert_true(record.input is Some(_))
  guard report.items[1] is Rejected(failure) else {
    fail("expected query failure")
  }
  assert_eq(failure.stage, "query")
  assert_true(failure.diagnostic is Json::Object(_))
}

///|
test "query catalog discovers and evaluates named expressions" {
  let catalog = try! QueryCatalog::default()
  catalog.register("active", "people[?active].name")
  catalog.register("count", "length(people)")
  let input = try! @json.parse(
    "{\"people\":[{\"name\":\"Ada\",\"active\":true},{\"name\":\"Lin\",\"active\":false}]}",
  )
  let entries = catalog.entries()
  assert_eq(entries.length(), 2)
  assert_eq(entries[0].name, "active")
  assert_eq(entries[1].name, "count")
  json_inspect(try! catalog.search("active", input), content=["Ada"])
  let results = catalog.search_all(input)
  assert_eq(results.length(), 2)
  assert_eq(catalog.stats().entries, 2)
  assert_true(catalog.contains("count"))
  catalog.remove("count")
  assert_true(!catalog.contains("count"))
  guard catalog_items_to_json(results[:]) is Json::Array(_) else {
    fail("expected catalog result JSON")
  }
}
