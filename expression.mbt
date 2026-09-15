///|
/// A compiled and reusable JMESPath expression.
pub struct Expression {
  source : String
  ast : Ast
  limits : Limits
}

///|
/// Compile a JMESPath expression once for repeated evaluation.
pub fn compile(
  source : String,
  limits? : Limits = Limits::default(),
) -> Expression raise JmesError {
  let tokens = match lex(source, limits) {
    Ok(tokens) => tokens
    Err(error) => raise error
  }
  let parser : Parser = { tokens, limits, index: 0, nodes: 0, }
  { source, ast: parser.parse(), limits, }
}

///|
/// Return the original source of a compiled expression.
pub fn Expression::source(self : Expression) -> String {
  self.source
}
