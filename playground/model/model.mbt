///|
fn input_error(message : String) -> Json {
  {
    "ok": false,
    "stage": "input",
    "message": message,
    "diagnostic": Json::null(),
  }
}

///|
fn query_error(error : @jmespath.JmesError, source : String) -> Json {
  {
    "ok": false,
    "stage": "query",
    "message": error.message(),
    "diagnostic": error.diagnostic(source).to_json(),
  }
}

///|
fn success_response(
  result : Json,
  plan : @jmespath.QueryPlan,
  trace : @jmespath.TraceReport,
) -> Json {
  {
    "ok": true,
    "stage": "complete",
    "result": result,
    "result_text": result.stringify(indent=2),
    "plan": plan.to_json(),
    "trace": trace.to_json(),
  }
}

///|
/// Execute a complete playground request and return a JSON response envelope.
pub fn run(expression_source : String, input_source : String) -> String {
  let input = @json.parse(input_source) catch {
    error => return input_error(error.to_string()).stringify()
  }
  let expression = @jmespath.compile(expression_source) catch {
    error => return query_error(error, expression_source).stringify()
  }
  let plan = expression.explain()
  let trace = expression.trace(input, options={
    max_events: 500,
    preview_characters: 100,
  }) catch {
    error => return query_error(error, expression_source).stringify()
  }
  success_response(trace.result, plan, trace).stringify()
}
