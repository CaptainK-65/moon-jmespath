///|
priv struct EvalContext {
  limits : Limits
  custom_functions : Map[String, RegisteredFunction]
  trace : TraceRecorder?
  mut steps : Int
}

///|
fn EvalContext::tick(self : EvalContext, depth : Int) -> Unit raise JmesError {
  self.steps = self.steps + 1
  if self.steps > self.limits.max_steps {
    raise JmesError::new(LimitExceeded, "evaluation step limit exceeded", 0)
  }
  if depth > self.limits.max_depth {
    raise JmesError::new(LimitExceeded, "evaluation depth limit exceeded", 0)
  }
}

///|
fn is_truthy(value : Json) -> Bool {
  match value {
    Json::Null | Json::False => false
    Json::String(value) => !value.is_empty()
    Json::Array(values) => !values.is_empty()
    Json::Object(values) => !values.is_empty()
    _ => true
  }
}

///|
fn evaluate_field(input : Json, name : String) -> Json {
  match input {
    Json::Object(values) =>
      match values.get(name) {
        Some(value) => value
        None => Json::null()
      }
    _ => Json::null()
  }
}

///|
fn evaluate_index(input : Json, index : Int) -> Json {
  match input {
    Json::Array(values) => {
      let actual = if index < 0 { values.length() + index } else { index }
      if actual >= 0 && actual < values.length() {
        values[actual]
      } else {
        Json::null()
      }
    }
    _ => Json::null()
  }
}

///|
fn clamp(value : Int, minimum : Int, maximum : Int) -> Int {
  if value < minimum {
    minimum
  } else if value > maximum {
    maximum
  } else {
    value
  }
}

///|
fn evaluate_slice(
  input : Json,
  start : Int?,
  stop : Int?,
  step : Int?,
) -> Json raise JmesError {
  guard input is Json::Array(values) else { return Json::null() }
  let length = values.length()
  let stride = step.unwrap_or(1)
  if stride == 0 {
    raise JmesError::new(InvalidValue, "slice step cannot be zero", 0)
  }
  let result : Array[Json] = []
  if stride > 0 {
    let first_value = start.unwrap_or(0)
    let last_value = stop.unwrap_or(length)
    let first = clamp(
      if first_value < 0 {
        length + first_value
      } else {
        first_value
      },
      0,
      length,
    )
    let last = clamp(
      if last_value < 0 {
        length + last_value
      } else {
        last_value
      },
      0,
      length,
    )
    let mut i = first
    while i < last {
      result.push(values[i])
      i = i + stride
    }
  } else {
    let first = match start {
      None => length - 1
      Some(value) =>
        clamp(if value < 0 { length + value } else { value }, -1, length - 1)
    }
    let last = match stop {
      None => -1
      Some(value) =>
        clamp(if value < 0 { length + value } else { value }, -1, length - 1)
    }
    let mut i = first
    while i > last {
      if i >= 0 && i < length {
        result.push(values[i])
      }
      i = i + stride
    }
  }
  Json::array(result)
}

///|
fn compare_values(operation : CompareOp, left : Json, right : Json) -> Json {
  match operation {
    Equal => Json::boolean(left == right)
    NotEqual => Json::boolean(left != right)
    Less | LessOrEqual | Greater | GreaterOrEqual => {
      let ordering : Int? = match (left, right) {
        (Json::Number(a, ..), Json::Number(b, ..)) =>
          Some(if a < b { -1 } else if a > b { 1 } else { 0 })
        (Json::String(a), Json::String(b)) => Some(a.compare(b))
        _ => None
      }
      match ordering {
        None => Json::null()
        Some(ordering) =>
          Json::boolean(
            match operation {
              Less => ordering < 0
              LessOrEqual => ordering <= 0
              Greater => ordering > 0
              GreaterOrEqual => ordering >= 0
              _ => false
            },
          )
      }
    }
  }
}

///|
fn evaluate(
  ast : Ast,
  input : Json,
  context : EvalContext,
  depth : Int,
) -> Json raise JmesError {
  context.tick(depth)
  let result = match ast {
    Identity => input
    Field(name) => evaluate_field(input, name)
    Literal(value) => value
    Sequence(left, right) => {
      let value = evaluate(left, input, context, depth + 1)
      evaluate(right, value, context, depth + 1)
    }
    Index(base, index) =>
      evaluate_index(evaluate(base, input, context, depth + 1), index)
    Slice(base, start, stop, step) =>
      evaluate_slice(
        evaluate(base, input, context, depth + 1),
        start,
        stop,
        step,
      )
    Flatten(base) => {
      let value = evaluate(base, input, context, depth + 1)
      match value {
        Json::Array(values) => {
          let flattened : Array[Json] = []
          for value in values {
            match value {
              Json::Array(nested) =>
                for item in nested {
                  flattened.push(item)
                }
              _ => flattened.push(value)
            }
          }
          Json::array(flattened)
        }
        _ => Json::null()
      }
    }
    Values(base) => {
      let value = evaluate(base, input, context, depth + 1)
      match value {
        Json::Object(values) => {
          let result : Array[Json] = []
          for _, value in values {
            result.push(value)
          }
          Json::array(result)
        }
        _ => Json::null()
      }
    }
    Filter(base, predicate) => {
      let value = evaluate(base, input, context, depth + 1)
      match value {
        Json::Array(values) => {
          let result : Array[Json] = []
          for item in values {
            if is_truthy(evaluate(predicate, item, context, depth + 1)) {
              result.push(item)
            }
          }
          Json::array(result)
        }
        _ => Json::null()
      }
    }
    Projection(source, transform) => {
      let value = evaluate(source, input, context, depth + 1)
      match value {
        Json::Array(values) => {
          let result : Array[Json] = []
          for item in values {
            let projected = evaluate(transform, item, context, depth + 1)
            if !(projected is Json::Null) {
              result.push(projected)
            }
          }
          Json::array(result)
        }
        _ => Json::null()
      }
    }
    PipeExpr(left, right) => {
      let value = evaluate(left, input, context, depth + 1)
      evaluate(right, value, context, depth + 1)
    }
    OrExpr(left, right) => {
      let value = evaluate(left, input, context, depth + 1)
      if is_truthy(value) {
        value
      } else {
        evaluate(right, input, context, depth + 1)
      }
    }
    AndExpr(left, right) => {
      let value = evaluate(left, input, context, depth + 1)
      if is_truthy(value) {
        evaluate(right, input, context, depth + 1)
      } else {
        value
      }
    }
    NotExpr(value) =>
      Json::boolean(!is_truthy(evaluate(value, input, context, depth + 1)))
    Compare(operation, left, right) =>
      compare_values(
        operation,
        evaluate(left, input, context, depth + 1),
        evaluate(right, input, context, depth + 1),
      )
    MultiList(items) =>
      if input is Json::Null {
        Json::null()
      } else {
        let result : Array[Json] = []
        for item in items {
          result.push(evaluate(item, input, context, depth + 1))
        }
        Json::array(result)
      }
    MultiHash(entries) =>
      if input is Json::Null {
        Json::null()
      } else {
        let result : Map[String, Json] = Map([])
        for entry in entries {
          let (key, value) = entry
          result[key] = evaluate(value, input, context, depth + 1)
        }
        Json::object(result)
      }
    Function(name, arguments) =>
      evaluate_function(name, arguments, input, context, depth + 1)
    ExpressionRef(_) =>
      raise JmesError::new(
        InvalidValue,
        "an expression reference is only valid as a function argument",
        0,
      )
  }
  match context.trace {
    Some(recorder) => recorder.record(ast, input, result, depth)
    None => ()
  }
  result
}
