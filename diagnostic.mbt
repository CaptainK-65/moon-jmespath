///|
/// A one-based line/column location backed by UTF-16 source offsets.
pub(all) struct SourceSpan {
  start : Int
  end : Int
  line : Int
  column : Int
} derive(Debug, Eq, ToJson)

///|
/// A stable, serializable diagnostic for editors and command-line clients.
pub(all) struct Diagnostic {
  kind : ErrorKind
  message : String
  span : SourceSpan
  excerpt : String
} derive(Debug, Eq)

///|
fn bounded_offset(source : String, offset : Int) -> Int {
  if offset < 0 {
    0
  } else if offset > source.length() {
    source.length()
  } else {
    offset
  }
}

///|
fn locate_offset(source : String, offset : Int) -> (Int, Int, Int) {
  let bounded = bounded_offset(source, offset)
  let mut line = 1
  let mut column = 1
  let mut line_start = 0
  for i in 0..<bounded {
    if source[i] == '\n' {
      line = line + 1
      column = 1
      line_start = i + 1
    } else {
      column = column + 1
    }
  }
  (line, column, line_start)
}

///|
fn line_end_offset(source : String, start : Int) -> Int {
  let mut result = source.length()
  for i in start..<source.length() {
    if source[i] == '\n' {
      result = i
      break
    }
  }
  result
}

///|
pub fn JmesError::diagnostic(self : JmesError, source : String) -> Diagnostic {
  let offset = bounded_offset(source, self.offset())
  let (line, column, line_start) = locate_offset(source, offset)
  let line_end = line_end_offset(source, line_start)
  let end = if offset < source.length() { offset + 1 } else { offset }
  {
    kind: self.kind(),
    message: self.message(),
    span: { start: offset, end, line, column, },
    excerpt: source[line_start:line_end].to_owned(),
  }
}

///|
pub fn Diagnostic::to_json(self : Diagnostic) -> Json {
  {
    "kind": match self.kind {
      Syntax => "syntax"
      InvalidType => "invalid_type"
      InvalidValue => "invalid_value"
      UnknownFunction => "unknown_function"
      InvalidArity => "invalid_arity"
      LimitExceeded => "limit_exceeded"
    },
    "message": self.message,
    "span": self.span,
    "excerpt": self.excerpt,
  }
}
