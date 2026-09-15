///|
/// Public error category shared by parsing and evaluation.
pub(all) enum ErrorKind {
  Syntax
  InvalidType
  InvalidValue
  UnknownFunction
  InvalidArity
  LimitExceeded
} derive(Debug, Eq)

///|
/// A structured, catchable JMESPath error with source position when available.
pub(all) suberror JmesError {
  Fault(ErrorKind, String, Int)
} derive(Debug, Eq)

///|
fn JmesError::new(
  kind : ErrorKind,
  message : String,
  offset : Int,
) -> JmesError {
  Fault(kind, message, offset)
}

///|
/// Return the stable category of this error.
pub fn JmesError::kind(self : JmesError) -> ErrorKind {
  match self {
    Fault(kind, _, _) => kind
  }
}

///|
/// Return the human-readable diagnostic message.
pub fn JmesError::message(self : JmesError) -> String {
  match self {
    Fault(_, message, _) => message
  }
}

///|
/// Return the UTF-16 source offset, or zero for data-only errors.
pub fn JmesError::offset(self : JmesError) -> Int {
  match self {
    Fault(_, _, offset) => offset
  }
}

///|
/// Resource limits applied while compiling and evaluating an expression.
pub(all) struct Limits {
  max_expression_length : Int
  max_ast_nodes : Int
  max_depth : Int
  max_steps : Int
} derive(Debug, Eq)

///|
/// Conservative defaults suitable for untrusted expressions.
pub fn Limits::default() -> Limits {
  {
    max_expression_length: 16384,
    max_ast_nodes: 4096,
    max_depth: 128,
    max_steps: 100000,
  }
}
