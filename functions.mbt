///|
fn function_error(
  kind : ErrorKind,
  name : String,
  message : String,
) -> JmesError {
  JmesError::new(kind, "\{name}(): \{message}", 0)
}

///|
fn require_arity(
  name : String,
  arguments : Array[Ast],
  minimum : Int,
  maximum : Int,
) -> Unit raise JmesError {
  if arguments.length() < minimum || arguments.length() > maximum {
    let expected = if minimum == maximum {
      "exactly \{minimum}"
    } else if maximum == 2147483647 {
      "at least \{minimum}"
    } else {
      "between \{minimum} and \{maximum}"
    }
    raise function_error(
      InvalidArity,
      name,
      "expected \{expected} arguments, received \{arguments.length()}",
    )
  }
}

///|
fn evaluate_arguments(
  arguments : Array[Ast],
  input : Json,
  context : EvalContext,
  depth : Int,
) -> Array[Json] raise JmesError {
  let values : Array[Json] = []
  for argument in arguments {
    values.push(evaluate(argument, input, context, depth + 1))
  }
  values
}

///|
fn require_number(name : String, value : Json) -> Double raise JmesError {
  match value {
    Json::Number(value, ..) => value
    _ => raise function_error(InvalidType, name, "expected a number")
  }
}

///|
fn require_string(name : String, value : Json) -> String raise JmesError {
  match value {
    Json::String(value) => value
    _ => raise function_error(InvalidType, name, "expected a string")
  }
}

///|
fn require_array(name : String, value : Json) -> Array[Json] raise JmesError {
  match value {
    Json::Array(value) => value
    _ => raise function_error(InvalidType, name, "expected an array")
  }
}

///|
fn json_type(value : Json) -> String {
  match value {
    Json::Array(_) => "array"
    Json::False | Json::True => "boolean"
    Json::Null => "null"
    Json::Number(_, ..) => "number"
    Json::Object(_) => "object"
    Json::String(_) => "string"
  }
}

///|
fn json_order(left : Json, right : Json) -> Int {
  match (left, right) {
    (Json::Number(a, ..), Json::Number(b, ..)) => a.compare(b)
    (Json::String(a), Json::String(b)) => a.compare(b)
    _ => 0
  }
}

///|
fn validate_orderable_array(
  name : String,
  values : Array[Json],
) -> Unit raise JmesError {
  if values.is_empty() {
    return
  }
  let expected = json_type(values[0])
  if expected != "number" && expected != "string" {
    raise function_error(
      InvalidType,
      name,
      "array values must be numbers or strings",
    )
  }
  for value in values {
    if json_type(value) != expected {
      raise function_error(
        InvalidType,
        name,
        "array values must have one comparable type",
      )
    }
  }
}

///|
fn character_length(value : String) -> Int {
  let mut length = 0
  for _ in value {
    length = length + 1
  }
  length
}

///|
fn numeric_aggregate(
  name : String,
  values : Array[Json],
) -> Double raise JmesError {
  let mut total = 0.0
  for value in values {
    total = total + require_number(name, value)
  }
  total
}

///|
fn evaluate_expression_ref(
  name : String,
  argument : Ast,
) -> Ast raise JmesError {
  match argument {
    ExpressionRef(expression) => expression
    _ =>
      raise function_error(
        InvalidType,
        name,
        "expected an expression reference",
      )
  }
}

///|
fn evaluate_map_function(
  name : String,
  arguments : Array[Ast],
  input : Json,
  context : EvalContext,
  depth : Int,
) -> Json raise JmesError {
  require_arity(name, arguments, 2, 2)
  let expression = evaluate_expression_ref(name, arguments[0])
  let values = require_array(
    name,
    evaluate(arguments[1], input, context, depth + 1),
  )
  let result : Array[Json] = []
  for value in values {
    result.push(evaluate(expression, value, context, depth + 1))
  }
  Json::array(result)
}

///|
fn evaluate_by_function(
  name : String,
  arguments : Array[Ast],
  input : Json,
  context : EvalContext,
  depth : Int,
) -> Json raise JmesError {
  require_arity(name, arguments, 2, 2)
  let values = require_array(
    name,
    evaluate(arguments[0], input, context, depth + 1),
  )
  if values.is_empty() {
    return if name == "sort_by" { Json::array([]) } else { Json::null() }
  }
  let expression = evaluate_expression_ref(name, arguments[1])
  let keyed : Array[(Json, Json)] = []
  for value in values {
    keyed.push((evaluate(expression, value, context, depth + 1), value))
  }
  let keys = [ for pair in keyed => pair.0 ]
  validate_orderable_array(name, keys)
  if name == "sort_by" {
    keyed.sort_by((a, b) => json_order(a.0, b.0))
    Json::array([ for pair in keyed => pair.1 ])
  } else {
    let mut best = keyed[0]
    for pair in keyed[1:] {
      let ordering = json_order(pair.0, best.0)
      if (name == "max_by" && ordering > 0) ||
        (name == "min_by" && ordering < 0) {
        best = pair
      }
    }
    best.1
  }
}

///|
fn evaluate_function(
  name : String,
  arguments : Array[Ast],
  input : Json,
  context : EvalContext,
  depth : Int,
) -> Json raise JmesError {
  if name == "map" {
    return evaluate_map_function(name, arguments, input, context, depth)
  }
  if name == "sort_by" || name == "max_by" || name == "min_by" {
    return evaluate_by_function(name, arguments, input, context, depth)
  }
  if name == "not_null" {
    require_arity(name, arguments, 1, 2147483647)
    for argument in arguments {
      let value = evaluate(argument, input, context, depth + 1)
      if !(value is Json::Null) {
        return value
      }
    }
    return Json::null()
  }
  let values = evaluate_arguments(arguments, input, context, depth)
  match name {
    "abs" | "ceil" | "floor" => {
      require_arity(name, arguments, 1, 1)
      let number = require_number(name, values[0])
      let result = match name {
        "abs" => number.abs()
        "ceil" => number.ceil()
        _ => number.floor()
      }
      Json::number(result)
    }
    "avg" | "sum" => {
      require_arity(name, arguments, 1, 1)
      let array = require_array(name, values[0])
      let total = numeric_aggregate(name, array)
      if name == "avg" {
        if array.is_empty() {
          Json::null()
        } else {
          Json::number(total / array.length().to_double())
        }
      } else {
        Json::number(total)
      }
    }
    "contains" => {
      require_arity(name, arguments, 2, 2)
      let found = match values[0] {
        Json::String(subject) =>
          subject.contains(require_string(name, values[1]))
        Json::Array(subject) => subject.contains(values[1])
        _ =>
          raise function_error(InvalidType, name, "expected a string or array")
      }
      Json::boolean(found)
    }
    "ends_with" | "starts_with" => {
      require_arity(name, arguments, 2, 2)
      let subject = require_string(name, values[0])
      let search = require_string(name, values[1])
      Json::boolean(
        if name == "ends_with" {
          subject.has_suffix(search)
        } else {
          subject.has_prefix(search)
        },
      )
    }
    "join" => {
      require_arity(name, arguments, 2, 2)
      let separator = require_string(name, values[0])
      let array = require_array(name, values[1])
      let strings : Array[String] = []
      for value in array {
        strings.push(require_string(name, value))
      }
      Json::string(strings.join(separator))
    }
    "keys" | "values" => {
      require_arity(name, arguments, 1, 1)
      guard values[0] is Json::Object(object) else {
        raise function_error(InvalidType, name, "expected an object")
      }
      let result : Array[Json] = []
      for key, value in object {
        result.push(if name == "keys" { Json::string(key) } else { value })
      }
      Json::array(result)
    }
    "length" => {
      require_arity(name, arguments, 1, 1)
      let length = match values[0] {
        Json::String(value) => character_length(value)
        Json::Array(value) => value.length()
        Json::Object(value) => value.length()
        _ =>
          raise function_error(
            InvalidType,
            name,
            "expected a string, array, or object",
          )
      }
      Json::number(length.to_double())
    }
    "max" | "min" | "sort" => {
      require_arity(name, arguments, 1, 1)
      let array = require_array(name, values[0]).copy()
      validate_orderable_array(name, array)
      array.sort_by(json_order)
      if name == "sort" {
        Json::array(array)
      } else if array.is_empty() {
        Json::null()
      } else if name == "max" {
        array[array.length() - 1]
      } else {
        array[0]
      }
    }
    "merge" => {
      require_arity(name, arguments, 1, 2147483647)
      let merged : Map[String, Json] = Map([])
      for value in values {
        guard value is Json::Object(object) else {
          raise function_error(InvalidType, name, "expected only objects")
        }
        for key, entry in object {
          merged[key] = entry
        }
      }
      Json::object(merged)
    }
    "reverse" => {
      require_arity(name, arguments, 1, 1)
      match values[0] {
        Json::String(value) => Json::string(value.rev())
        Json::Array(value) => {
          let result : Array[Json] = []
          let mut i = value.length() - 1
          while i >= 0 {
            result.push(value[i])
            i = i - 1
          }
          Json::array(result)
        }
        _ =>
          raise function_error(InvalidType, name, "expected a string or array")
      }
    }
    "to_array" => {
      require_arity(name, arguments, 1, 1)
      match values[0] {
        Json::Array(_) => values[0]
        value => Json::array([value])
      }
    }
    "to_number" => {
      require_arity(name, arguments, 1, 1)
      match values[0] {
        Json::Number(_, ..) => values[0]
        Json::String(value) =>
          if @json.valid(value) {
            match (try! @json.parse(value)) {
              Json::Number(number, repr~) => Json::number(number, repr?)
              _ => Json::null()
            }
          } else {
            Json::null()
          }
        _ => Json::null()
      }
    }
    "to_string" => {
      require_arity(name, arguments, 1, 1)
      match values[0] {
        Json::String(_) => values[0]
        value => Json::string(value.stringify())
      }
    }
    "type" => {
      require_arity(name, arguments, 1, 1)
      Json::string(json_type(values[0]))
    }
    _ => raise function_error(UnknownFunction, name, "unknown function")
  }
}
