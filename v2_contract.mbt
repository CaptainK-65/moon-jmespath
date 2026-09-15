///|
/// Formal v0.2 source-location contract. Implementation lives in diagnostic.mbt.
declare pub type SourceSpan

///|
/// Formal v0.2 diagnostic contract. Implementation lives in diagnostic.mbt.
declare pub type Diagnostic

///|
/// Convert a structured engine error into a source-aware diagnostic.
declare pub fn JmesError::diagnostic(
  self : JmesError,
  source : String,
) -> Diagnostic

///|
/// Return a compact JSON representation suitable for tooling and web clients.
declare pub fn Diagnostic::to_json(self : Diagnostic) -> Json
