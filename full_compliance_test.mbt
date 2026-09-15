///|
struct ComplianceGroup {
  given : Json
  cases : Array[ComplianceCase]
} derive(FromJson)

///|
struct ComplianceCase {
  expression : String
  result : Json?
  error : String?
  bench : String?
} derive(FromJson)

///|
fn expected_error_kind(category : String) -> ErrorKind? {
  match category {
    "syntax" => Some(Syntax)
    "invalid-type" => Some(InvalidType)
    "invalid-value" => Some(InvalidValue)
    "unknown-function" => Some(UnknownFunction)
    "invalid-arity" => Some(InvalidArity)
    _ => None
  }
}

///|
fn compliance_error_name(kind : ErrorKind) -> String {
  match kind {
    Syntax => "syntax"
    InvalidType => "invalid-type"
    InvalidValue => "invalid-value"
    UnknownFunction => "unknown-function"
    InvalidArity => "invalid-arity"
    LimitExceeded => "limit-exceeded"
  }
}

///|
fn run_upstream_case(
  filename : String,
  group_index : Int,
  case_index : Int,
  given : Json,
  case : ComplianceCase,
) -> String? {
  let label = "\{filename}:\{group_index}:\{case_index} expression=\{case.expression}"
  if case.error is None && case.result is None && case.bench == Some("parse") {
    return try {
      ignore(compile(case.expression))
      None
    } catch {
      JmesError::Fault(kind, message, offset) =>
        Some(
          "\{label}: parse benchmark raised \{compliance_error_name(kind)} at \{offset}: \{message}",
        )
    }
  }
  match case.error {
    Some(category) => {
      let wanted = expected_error_kind(category)
      match wanted {
        None => Some("\{label}: unknown fixture error category \{category}")
        Some(wanted) =>
          try {
            let actual = search(case.expression, given)
            Some(
              "\{label}: expected error \{category}, got \{actual.stringify()}",
            )
          } catch {
            JmesError::Fault(kind, _, _) =>
              if kind == wanted {
                None
              } else {
                Some(
                  "\{label}: expected \{compliance_error_name(wanted)}, got \{compliance_error_name(kind)}",
                )
              }
          }
      }
    }
    None => {
      let wanted = case.result.unwrap_or(Json::null())
      try {
        let actual = search(case.expression, given)
        if actual == wanted {
          None
        } else {
          Some(
            "\{label}: expected \{wanted.stringify()}, got \{actual.stringify()}",
          )
        }
      } catch {
        JmesError::Fault(kind, message, offset) =>
          Some(
            "\{label}: unexpected \{compliance_error_name(kind)} at \{offset}: \{message}",
          )
      }
    }
  }
}

///|
test "upstream JMESPath compliance corpus" {
  let failures : Array[String] = []
  let mut total = 0
  let mut failed = 0
  for fixture in compliance_fixture_sources {
    let (filename, source) = fixture
    let document = try! @json.parse(source)
    let groups : Array[ComplianceGroup] = try! @json.from_json(document)
    for group_index, group in groups {
      for case_index, case in group.cases {
        total = total + 1
        match
          run_upstream_case(
            filename,
            group_index,
            case_index,
            group.given,
            case,
          ) {
          Some(failure) => {
            failed = failed + 1
            if failures.length() < 100 {
              failures.push(failure)
            }
          }
          None => ()
        }
      }
    }
  }
  if !failures.is_empty() {
    fail(
      "JMESPath compliance failures (showing \{failures.length()} of \{failed}, \{total} cases):\n" +
      failures.join("\n"),
    )
  }
}
