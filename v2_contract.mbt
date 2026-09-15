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

///|
/// Formal v0.2 reusable-engine contract. Implementation lives in engine.mbt.
declare pub type Engine

///|
/// Formal v0.2 engine-metrics contract. Implementation lives in engine.mbt.
declare pub type EngineStats

///|
/// Formal v0.2 isolated batch-result contract. Implementation lives in engine.mbt.
declare pub type BatchItem

///|
declare pub fn Engine::new(
  limits? : Limits,
  cache_capacity? : Int,
) -> Engine raise JmesError

///|
declare pub fn Engine::register_function(
  self : Engine,
  name : String,
  minimum_arity : Int,
  maximum_arity : Int?,
  handler : (ArrayView[Json]) -> Json raise JmesError,
) -> Unit raise JmesError

///|
declare pub fn Engine::unregister_function(self : Engine, name : String) -> Unit

///|
declare pub fn Engine::compile(
  self : Engine,
  source : String,
) -> Expression raise JmesError

///|
declare pub fn Engine::search(
  self : Engine,
  source : String,
  input : Json,
) -> Json raise JmesError

///|
declare pub fn Engine::search_batch(
  self : Engine,
  source : String,
  inputs : ArrayView[Json],
) -> Array[BatchItem] raise JmesError

///|
declare pub fn Engine::clear_cache(self : Engine) -> Unit

///|
declare pub fn Engine::stats(self : Engine) -> EngineStats
