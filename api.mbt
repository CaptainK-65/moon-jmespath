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
/// A structured JMESPath error with source position when available.
pub(all) struct JmesError {
  kind : ErrorKind
  message : String
  offset : Int
} derive(Debug, Eq)

///|
fn JmesError::new(
  kind : ErrorKind,
  message : String,
  offset : Int,
) -> JmesError {
  { kind, message, offset, }
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
