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

///|
/// Formal v0.2 static-analysis contracts. Implementation lives in analysis.mbt.
declare pub type AnalysisSeverity

///|
declare pub type AnalysisFinding

///|
declare pub type AnalysisOptions

///|
declare pub type ExpressionAnalysis

///|
declare pub fn AnalysisOptions::default() -> AnalysisOptions

///|
declare pub fn Expression::analyze(
  self : Expression,
  options? : AnalysisOptions,
) -> ExpressionAnalysis

///|
declare pub fn ExpressionAnalysis::to_json(self : ExpressionAnalysis) -> Json

///|
/// Formal v0.2 pipeline contracts. Implementation lives in pipeline.mbt.
declare pub type Pipeline

///|
declare pub type PipelineStats

///|
declare pub type PipelineReport

///|
declare pub fn compile_pipeline(
  sources : ArrayView[String],
  limits? : Limits,
) -> Pipeline raise JmesError

///|
declare pub fn Engine::compile_pipeline(
  self : Engine,
  sources : ArrayView[String],
) -> Pipeline raise JmesError

///|
declare pub fn Pipeline::search(
  self : Pipeline,
  input : Json,
) -> PipelineReport raise JmesError

///|
declare pub fn Engine::search_pipeline(
  self : Engine,
  pipeline : Pipeline,
  input : Json,
) -> PipelineReport raise JmesError

///|
declare pub fn Pipeline::sources(self : Pipeline) -> Array[String]

///|
declare pub fn Pipeline::stats(self : Pipeline) -> PipelineStats

///|
declare pub fn Pipeline::explain(self : Pipeline) -> Array[QueryPlan]

///|
declare pub fn PipelineReport::to_json(self : PipelineReport) -> Json

///|
/// Formal v0.2 NDJSON contracts. Implementation lives in ndjson.mbt.
declare pub type NdjsonOptions

///|
declare pub type NdjsonRecord

///|
declare pub type NdjsonFailure

///|
declare pub type NdjsonItem

///|
declare pub type NdjsonReport

///|
declare pub fn NdjsonOptions::default() -> NdjsonOptions

///|
declare pub fn search_ndjson(
  source : String,
  document : String,
  limits? : Limits,
  options? : NdjsonOptions,
) -> NdjsonReport raise JmesError

///|
declare pub fn Engine::search_ndjson(
  self : Engine,
  source : String,
  document : String,
  options? : NdjsonOptions,
) -> NdjsonReport raise JmesError

///|
declare pub fn NdjsonReport::to_json(self : NdjsonReport) -> Json

///|
/// Formal v0.2 query-catalog contracts. Implementation lives in catalog.mbt.
declare pub type CatalogEntry

///|
declare pub type CatalogItem

///|
declare pub type CatalogStats

///|
declare pub type QueryCatalog

///|
declare pub fn QueryCatalog::new(engine : Engine) -> QueryCatalog

///|
declare pub fn QueryCatalog::default() -> QueryCatalog raise JmesError

///|
declare pub fn QueryCatalog::register(
  self : QueryCatalog,
  name : String,
  source : String,
) -> Unit raise JmesError

///|
declare pub fn QueryCatalog::remove(self : QueryCatalog, name : String) -> Unit

///|
declare pub fn QueryCatalog::contains(
  self : QueryCatalog,
  name : String,
) -> Bool

///|
declare pub fn QueryCatalog::entries(self : QueryCatalog) -> Array[CatalogEntry]

///|
declare pub fn QueryCatalog::search(
  self : QueryCatalog,
  name : String,
  input : Json,
) -> Json raise JmesError

///|
declare pub fn QueryCatalog::search_all(
  self : QueryCatalog,
  input : Json,
) -> Array[CatalogItem]

///|
declare pub fn QueryCatalog::stats(self : QueryCatalog) -> CatalogStats

///|
declare pub fn catalog_items_to_json(items : ArrayView[CatalogItem]) -> Json
