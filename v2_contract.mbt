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

///|
/// Formal v0.2 inspection contracts. Implementations live in inspection.mbt.
declare pub type PlanStats

///|
declare pub type QueryPlan

///|
declare pub fn Expression::ast_json(self : Expression) -> Json

///|
declare pub fn Expression::explain(self : Expression) -> QueryPlan

///|
declare pub fn QueryPlan::to_json(self : QueryPlan) -> Json

///|
/// Formal v0.2 trace contracts. Implementations live in trace.mbt.
declare pub type TraceOptions

///|
declare pub type TraceEvent

///|
declare pub type TraceReport

///|
declare pub fn TraceOptions::default() -> TraceOptions

///|
declare pub fn Expression::trace(
  self : Expression,
  input : Json,
  options? : TraceOptions,
) -> TraceReport raise JmesError

///|
declare pub fn Engine::trace(
  self : Engine,
  source : String,
  input : Json,
  options? : TraceOptions,
) -> TraceReport raise JmesError

///|
declare pub fn TraceReport::to_json(self : TraceReport) -> Json
