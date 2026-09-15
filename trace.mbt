///|
/// Controls trace volume and intermediate-value previews.
pub(all) struct TraceOptions {
  max_events : Int
  preview_characters : Int
} derive(Debug, Eq)

///|
/// One completed AST evaluation step.
pub(all) struct TraceEvent {
  sequence : Int
  depth : Int
  operation : String
  input_type : String
  output_type : String
  output_preview : String
} derive(Debug, Eq, ToJson)

///|
/// Successful evaluation output plus a bounded execution trace.
pub(all) struct TraceReport {
  source : String
  result : Json
  events : Array[TraceEvent]
  total_steps : Int
  truncated : Bool
} derive(Debug, Eq)

///|
priv struct TraceRecorder {
  events : Array[TraceEvent]
  max_events : Int
  preview_characters : Int
  mut truncated : Bool
}

///|
pub fn TraceOptions::default() -> TraceOptions {
  { max_events: 1000, preview_characters: 120, }
}

///|
fn limited_preview(value : Json, limit : Int) -> String {
  if limit <= 0 {
    return ""
  }
  let source = value.stringify()
  let builder = StringBuilder()
  let mut count = 0
  for character in source {
    if count >= limit {
      builder.write_string("…")
      break
    }
    builder.write_char(character)
    count = count + 1
  }
  builder.to_string()
}

///|
fn TraceRecorder::record(
  self : TraceRecorder,
  ast : Ast,
  input : Json,
  output : Json,
  depth : Int,
) -> Unit {
  if self.events.length() >= self.max_events {
    self.truncated = true
    return
  }
  self.events.push({
    sequence: self.events.length(),
    depth,
    operation: ast_operation_name(ast),
    input_type: json_type(input),
    output_type: json_type(output),
    output_preview: limited_preview(output, self.preview_characters),
  })
}

///|
fn trace_recorder(options : TraceOptions) -> TraceRecorder {
  {
    events: [],
    max_events: if options.max_events < 0 {
      0
    } else {
      options.max_events
    },
    preview_characters: if options.preview_characters < 0 {
      0
    } else {
      options.preview_characters
    },
    truncated: false,
  }
}

///|
fn Expression::trace_with_functions(
  self : Expression,
  input : Json,
  custom_functions : Map[String, RegisteredFunction],
  options : TraceOptions,
) -> TraceReport raise JmesError {
  let recorder = trace_recorder(options)
  let context : EvalContext = {
    limits: self.limits,
    custom_functions,
    trace: Some(recorder),
    steps: 0,
  }
  let result = evaluate(self.ast, input, context, 0)
  {
    source: self.source,
    result,
    events: recorder.events,
    total_steps: context.steps,
    truncated: recorder.truncated,
  }
}

///|
/// Evaluate this expression and return a bounded, post-order execution trace.
pub fn Expression::trace(
  self : Expression,
  input : Json,
  options? : TraceOptions = TraceOptions::default(),
) -> TraceReport raise JmesError {
  self.trace_with_functions(input, Map([]), options)
}

///|
/// Compile through the engine cache and trace with registered custom functions.
pub fn Engine::trace(
  self : Engine,
  source : String,
  input : Json,
  options? : TraceOptions = TraceOptions::default(),
) -> TraceReport raise JmesError {
  self.compile(source).trace_with_functions(input, self.functions, options)
}

///|
pub fn TraceReport::to_json(self : TraceReport) -> Json {
  {
    "source": self.source,
    "result": self.result,
    "events": self.events,
    "total_steps": self.total_steps,
    "truncated": self.truncated,
  }
}
