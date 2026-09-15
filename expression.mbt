///|
/// A compiled and reusable JMESPath expression.
pub struct Expression {
  priv source : String
  priv ast : Ast
  priv limits : Limits
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

///|
/// Evaluate this compiled expression against a JSON value.
pub fn Expression::search(
  self : Expression,
  input : Json,
) -> Json raise JmesError {
  self.search_with_functions(input, Map([]))
}

///|
fn Expression::search_with_functions(
  self : Expression,
  input : Json,
  custom_functions : Map[String, RegisteredFunction],
) -> Json raise JmesError {
  let context : EvalContext = {
    limits: self.limits,
    custom_functions,
    steps: 0,
  }
  evaluate(self.ast, input, context, 0)
}

///|
/// Compile and evaluate a JMESPath expression in one call.
pub fn search(
  source : String,
  input : Json,
  limits? : Limits = Limits::default(),
) -> Json raise JmesError {
  compile(source, limits~).search(input)
}
