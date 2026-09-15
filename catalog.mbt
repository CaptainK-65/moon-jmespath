///|
/// Public metadata for one named, precompiled query.
pub(all) struct CatalogEntry {
  name : String
  source : String
  stats : PlanStats
} derive(Debug, Eq)

///|
/// One isolated result from evaluating every catalog entry.
pub(all) enum CatalogItem {
  Value(String, Json)
  Failure(String, Diagnostic)
} derive(Debug, Eq)

///|
/// Aggregate metrics for a named query catalog.
pub(all) struct CatalogStats {
  entries : Int
  total_nodes : Int
  total_projections : Int
  total_functions : Int
} derive(Debug, Eq, ToJson)

///|
/// A named collection of expressions backed by one extensible Engine.
pub struct QueryCatalog {
  priv engine : Engine
  priv sources : Map[String, String]
  priv expressions : Map[String, Expression]
}

///|
pub fn QueryCatalog::new(engine : Engine) -> QueryCatalog {
  { engine, sources: Map([]), expressions: Map([]), }
}

///|
/// Create a catalog backed by an Engine with default limits and cache capacity.
pub fn QueryCatalog::default() -> QueryCatalog raise JmesError {
  QueryCatalog::new(Engine::new())
}

///|
fn validate_catalog_name(name : String) -> Unit raise JmesError {
  if name.trim().is_empty() {
    raise JmesError::new(InvalidValue, "catalog query name cannot be empty", 0)
  }
}

///|
/// Compile and insert or replace a named query.
pub fn QueryCatalog::register(
  self : QueryCatalog,
  name : String,
  source : String,
) -> Unit raise JmesError {
  validate_catalog_name(name)
  let expression = self.engine.compile(source)
  self.sources[name] = source
  self.expressions[name] = expression
}

///|
/// Remove a query. Removing an unknown name is a no-op.
pub fn QueryCatalog::remove(self : QueryCatalog, name : String) -> Unit {
  self.sources.remove(name)
  self.expressions.remove(name)
}

///|
pub fn QueryCatalog::contains(self : QueryCatalog, name : String) -> Bool {
  self.expressions.contains(name)
}

///|
/// Return sorted metadata suitable for discovery UIs and configuration tools.
pub fn QueryCatalog::entries(self : QueryCatalog) -> Array[CatalogEntry] {
  let names : Array[String] = []
  for name, _ in self.sources {
    names.push(name)
  }
  names.sort_by((left, right) => left.lexical_compare(right))
  let entries : Array[CatalogEntry] = []
  for name in names {
    guard self.sources.get(name) is Some(source) else { continue }
    guard self.expressions.get(name) is Some(expression) else { continue }
    entries.push({ name, source, stats: collect_plan_stats(expression.ast), })
  }
  entries
}

///|
fn unknown_catalog_query(name : String) -> JmesError {
  JmesError::new(InvalidValue, "unknown catalog query \{name}", 0)
}

///|
/// Evaluate one named query with the catalog engine's custom functions.
pub fn QueryCatalog::search(
  self : QueryCatalog,
  name : String,
  input : Json,
) -> Json raise JmesError {
  match self.expressions.get(name) {
    Some(expression) =>
      expression.search_with_functions(input, self.engine.functions)
    None => raise unknown_catalog_query(name)
  }
}

///|
/// Evaluate every named query in sorted order and isolate evaluation failures.
pub fn QueryCatalog::search_all(
  self : QueryCatalog,
  input : Json,
) -> Array[CatalogItem] {
  let output : Array[CatalogItem] = []
  for entry in self.entries() {
    guard self.expressions.get(entry.name) is Some(expression) else { continue }
    try expression.search_with_functions(input, self.engine.functions) catch {
      error => output.push(Failure(entry.name, error.diagnostic(entry.source)))
    } noraise {
      value => output.push(Value(entry.name, value))
    }
  }
  output
}

///|
pub fn QueryCatalog::stats(self : QueryCatalog) -> CatalogStats {
  let mut total_nodes = 0
  let mut total_projections = 0
  let mut total_functions = 0
  for entry in self.entries() {
    total_nodes = total_nodes + entry.stats.nodes
    total_projections = total_projections + entry.stats.projections
    total_functions = total_functions + entry.stats.functions
  }
  {
    entries: self.expressions.length(),
    total_nodes,
    total_projections,
    total_functions,
  }
}

///|
fn catalog_item_to_json(item : CatalogItem) -> Json {
  match item {
    Value(name, value) => { "name": name, "status": "value", "value": value }
    Failure(name, diagnostic) =>
      { "name": name, "status": "failure", "diagnostic": diagnostic.to_json() }
  }
}

///|
pub fn catalog_items_to_json(items : ArrayView[CatalogItem]) -> Json {
  Json::array([ for item in items => catalog_item_to_json(item) ])
}
