///|
/// Controls line handling and failure behavior for NDJSON processing.
pub(all) struct NdjsonOptions {
  skip_blank_lines : Bool
  continue_on_error : Bool
  include_input : Bool
} derive(Debug, Eq)

///|
/// One successfully parsed and transformed NDJSON record.
pub(all) struct NdjsonRecord {
  line : Int
  input : Json?
  output : Json
} derive(Debug, Eq)

///|
/// A parse or evaluation failure tied to its one-based input line.
pub(all) struct NdjsonFailure {
  line : Int
  stage : String
  message : String
  diagnostic : Json
} derive(Debug, Eq)

///|
/// One ordered NDJSON processing outcome.
pub(all) enum NdjsonItem {
  Record(NdjsonRecord)
  Rejected(NdjsonFailure)
} derive(Debug, Eq)

///|
/// Aggregate output of a compile-once NDJSON transformation.
pub(all) struct NdjsonReport {
  items : Array[NdjsonItem]
  processed : Int
  succeeded : Int
  failed : Int
  stopped_early : Bool
} derive(Debug, Eq)

///|
priv struct NdjsonAccumulator {
  items : Array[NdjsonItem]
  mut processed : Int
  mut succeeded : Int
  mut failed : Int
  mut stopped_early : Bool
}

///|
pub fn NdjsonOptions::default() -> NdjsonOptions {
  { skip_blank_lines: true, continue_on_error: true, include_input: false, }
}

///|
fn NdjsonAccumulator::accept(
  self : NdjsonAccumulator,
  line : Int,
  input : Json,
  output : Json,
  include_input : Bool,
) -> Unit {
  self.processed = self.processed + 1
  self.succeeded = self.succeeded + 1
  self.items.push(
    Record({
      line,
      input: if include_input {
        Some(input)
      } else {
        None
      },
      output,
    }),
  )
}

///|
fn NdjsonAccumulator::reject(
  self : NdjsonAccumulator,
  failure : NdjsonFailure,
) -> Unit {
  self.processed = self.processed + 1
  self.failed = self.failed + 1
  self.items.push(Rejected(failure))
}

///|
fn NdjsonAccumulator::finish(self : NdjsonAccumulator) -> NdjsonReport {
  {
    items: self.items,
    processed: self.processed,
    succeeded: self.succeeded,
    failed: self.failed,
    stopped_early: self.stopped_early,
  }
}

///|
fn parse_ndjson_line(
  line_number : Int,
  source : StringView,
) -> Result[Json, NdjsonFailure] {
  try @json.parse(source) catch {
    error =>
      Err({
        line: line_number,
        stage: "input",
        message: error.to_string(),
        diagnostic: Json::null(),
      })
  } noraise {
    value => Ok(value)
  }
}

///|
fn evaluate_ndjson_line(
  expression : Expression,
  source : String,
  line_number : Int,
  input : Json,
  custom_functions : Map[String, RegisteredFunction],
) -> Result[Json, NdjsonFailure] {
  try expression.search_with_functions(input, custom_functions) catch {
    error =>
      Err({
        line: line_number,
        stage: "query",
        message: error.message(),
        diagnostic: error.diagnostic(source).to_json(),
      })
  } noraise {
    value => Ok(value)
  }
}

///|
fn process_ndjson(
  expression : Expression,
  source : String,
  document : String,
  custom_functions : Map[String, RegisteredFunction],
  options : NdjsonOptions,
) -> NdjsonReport {
  let accumulator : NdjsonAccumulator = {
    items: [],
    processed: 0,
    succeeded: 0,
    failed: 0,
    stopped_early: false,
  }
  for index, raw_line in document.split("\n") {
    let line_number = index + 1
    let line = raw_line.to_owned().trim()
    if line.is_empty() && options.skip_blank_lines {
      continue
    }
    match parse_ndjson_line(line_number, line) {
      Err(failure) => {
        accumulator.reject(failure)
        if !options.continue_on_error {
          accumulator.stopped_early = true
          break
        }
      }
      Ok(input) =>
        match
          evaluate_ndjson_line(
            expression, source, line_number, input, custom_functions,
          ) {
          Ok(output) =>
            accumulator.accept(
              line_number,
              input,
              output,
              options.include_input,
            )
          Err(failure) => {
            accumulator.reject(failure)
            if !options.continue_on_error {
              accumulator.stopped_early = true
              break
            }
          }
        }
    }
  }
  accumulator.finish()
}

///|
/// Transform newline-delimited JSON using a single compiled expression.
pub fn search_ndjson(
  source : String,
  document : String,
  limits? : Limits = Limits::default(),
  options? : NdjsonOptions = NdjsonOptions::default(),
) -> NdjsonReport raise JmesError {
  let expression = compile(source, limits~)
  process_ndjson(expression, source, document, Map([]), options)
}

///|
/// Transform NDJSON using this engine's cache and custom functions.
pub fn Engine::search_ndjson(
  self : Engine,
  source : String,
  document : String,
  options? : NdjsonOptions = NdjsonOptions::default(),
) -> NdjsonReport raise JmesError {
  let expression = self.compile(source)
  process_ndjson(expression, source, document, self.functions, options)
}

///|
fn ndjson_item_to_json(item : NdjsonItem) -> Json {
  match item {
    Record(record) =>
      {
        "status": "record",
        "line": record.line,
        "input": record.input,
        "output": record.output,
      }
    Rejected(failure) =>
      {
        "status": "rejected",
        "line": failure.line,
        "stage": failure.stage,
        "message": failure.message,
        "diagnostic": failure.diagnostic,
      }
  }
}

///|
pub fn NdjsonReport::to_json(self : NdjsonReport) -> Json {
  {
    "items": Json::array(
      [
        for item in self.items => ndjson_item_to_json(item)
      ],
    ),
    "processed": self.processed,
    "succeeded": self.succeeded,
    "failed": self.failed,
    "stopped_early": self.stopped_early,
  }
}
