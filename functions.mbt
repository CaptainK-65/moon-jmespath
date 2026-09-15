///|
fn evaluate_function(
  name : String,
  _arguments : Array[Ast],
  _input : Json,
  _context : EvalContext,
  _depth : Int,
) -> Json raise JmesError {
  raise JmesError::new(UnknownFunction, "unknown function: \{name}", 0)
}
