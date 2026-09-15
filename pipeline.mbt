///|
/// Metrics for a compiled multi-stage transformation pipeline.
pub(all) struct PipelineStats {
  stages : Int
  total_nodes : Int
  max_stage_depth : Int
  projections : Int
  functions : Int
} derive(Debug, Eq, ToJson)

///|
/// A successful pipeline evaluation including every intermediate value.
pub(all) struct PipelineReport {
  result : Json
  intermediate : Array[Json]
} derive(Debug, Eq)

///|
/// A compiled sequence of expressions whose outputs feed subsequent stages.
pub struct Pipeline {
  priv sources : Array[String]
  priv expressions : Array[Expression]
  priv stats : PipelineStats
}

///|
fn pipeline_stats(expressions : Array[Expression]) -> PipelineStats {
  let mut total_nodes = 0
  let mut max_stage_depth = 0
  let mut projections = 0
  let mut functions = 0
  for expression in expressions {
    let stats = collect_plan_stats(expression.ast)
    total_nodes = total_nodes + stats.nodes
    projections = projections + stats.projections
    functions = functions + stats.functions
    if stats.max_depth > max_stage_depth {
      max_stage_depth = stats.max_depth
    }
  }
  {
    stages: expressions.length(),
    total_nodes,
    max_stage_depth,
    projections,
    functions,
  }
}

///|
fn ensure_pipeline_not_empty(length : Int) -> Unit raise JmesError {
  if length == 0 {
    raise JmesError::new(
      InvalidValue,
      "a query pipeline requires at least one stage",
      0,
    )
  }
}

///|
/// Compile an ordered pipeline with shared limits.
pub fn compile_pipeline(
  sources : ArrayView[String],
  limits? : Limits = Limits::default(),
) -> Pipeline raise JmesError {
  ensure_pipeline_not_empty(sources.length())
  let owned_sources : Array[String] = []
  let expressions : Array[Expression] = []
  for source in sources {
    owned_sources.push(source)
    expressions.push(compile(source, limits~))
  }
  { sources: owned_sources, expressions, stats: pipeline_stats(expressions), }
}

///|
/// Compile a pipeline through this engine's shared LRU cache.
pub fn Engine::compile_pipeline(
  self : Engine,
  sources : ArrayView[String],
) -> Pipeline raise JmesError {
  ensure_pipeline_not_empty(sources.length())
  let owned_sources : Array[String] = []
  let expressions : Array[Expression] = []
  for source in sources {
    owned_sources.push(source)
    expressions.push(self.compile(source))
  }
  { sources: owned_sources, expressions, stats: pipeline_stats(expressions), }
}

///|
fn Pipeline::run_with_functions(
  self : Pipeline,
  input : Json,
  custom_functions : Map[String, RegisteredFunction],
) -> PipelineReport raise JmesError {
  let intermediate : Array[Json] = []
  let mut current = input
  for expression in self.expressions {
    current = expression.search_with_functions(current, custom_functions)
    intermediate.push(current)
  }
  { result: current, intermediate, }
}

///|
/// Run all stages using only standard JMESPath functions.
pub fn Pipeline::search(
  self : Pipeline,
  input : Json,
) -> PipelineReport raise JmesError {
  self.run_with_functions(input, Map([]))
}

///|
/// Run a compiled pipeline with this engine's custom-function registry.
pub fn Engine::search_pipeline(
  self : Engine,
  pipeline : Pipeline,
  input : Json,
) -> PipelineReport raise JmesError {
  pipeline.run_with_functions(input, self.functions)
}

///|
/// Return an independent copy of the ordered source expressions.
pub fn Pipeline::sources(self : Pipeline) -> Array[String] {
  self.sources.copy()
}

///|
pub fn Pipeline::stats(self : Pipeline) -> PipelineStats {
  self.stats
}

///|
/// Explain every stage through the stable public plan representation.
pub fn Pipeline::explain(self : Pipeline) -> Array[QueryPlan] {
  [
    for expression in self.expressions => expression.explain()
  ]
}

///|
pub fn PipelineReport::to_json(self : PipelineReport) -> Json {
  { "result": self.result, "intermediate": self.intermediate }
}
