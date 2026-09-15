///|
priv struct RegisteredFunction {
  minimum_arity : Int
  maximum_arity : Int?
  handler : (ArrayView[Json]) -> Json raise JmesError
}

///|
/// Runtime metrics for an extensible engine instance.
pub(all) struct EngineStats {
  cache_entries : Int
  cache_hits : Int
  cache_misses : Int
  custom_functions : Int
} derive(Debug, Eq)

///|
/// The outcome of evaluating one input in an isolated batch.
pub(all) enum BatchItem {
  Value(Json)
  Failure(Int, Diagnostic)
} derive(Debug, Eq)

///|
/// A reusable evaluator with bounded compilation caching and custom functions.
pub struct Engine {
  priv limits : Limits
  priv cache_capacity : Int
  priv cache : Map[String, Expression]
  priv cache_order : Array[String]
  priv functions : Map[String, RegisteredFunction]
  priv mut cache_hits : Int
  priv mut cache_misses : Int
}

///|
/// Create an engine. A zero cache capacity disables compilation caching.
pub fn Engine::new(
  limits? : Limits = Limits::default(),
  cache_capacity? : Int = 128,
) -> Engine raise JmesError {
  if cache_capacity < 0 {
    raise JmesError::new(
      InvalidValue,
      "engine cache capacity cannot be negative",
      0,
    )
  }
  {
    limits,
    cache_capacity,
    cache: Map([]),
    cache_order: [],
    functions: Map([]),
    cache_hits: 0,
    cache_misses: 0,
  }
}

///|
fn valid_custom_function_name(name : String) -> Bool {
  if name.is_empty() || !is_identifier_start(name[0]) {
    return false
  }
  for i in 1..<name.length() {
    if !is_identifier_continue(name[i]) {
      return false
    }
  }
  true
}

///|
fn is_standard_function(name : String) -> Bool {
  match name {
    "abs"
    | "avg"
    | "ceil"
    | "contains"
    | "ends_with"
    | "floor"
    | "join"
    | "keys"
    | "length"
    | "map"
    | "max"
    | "max_by"
    | "merge"
    | "min"
    | "min_by"
    | "not_null"
    | "reverse"
    | "sort"
    | "sort_by"
    | "starts_with"
    | "sum"
    | "to_array"
    | "to_number"
    | "to_string"
    | "type"
    | "values" => true
    _ => false
  }
}

///|
/// Register a value-only custom function.
///
/// Standard JMESPath function names cannot be replaced. Passing `None` as the
/// maximum arity creates a variadic function.
pub fn Engine::register_function(
  self : Engine,
  name : String,
  minimum_arity : Int,
  maximum_arity : Int?,
  handler : (ArrayView[Json]) -> Json raise JmesError,
) -> Unit raise JmesError {
  if !valid_custom_function_name(name) {
    raise JmesError::new(InvalidValue, "invalid custom function name", 0)
  }
  if is_standard_function(name) {
    raise JmesError::new(
      InvalidValue,
      "standard function \{name} cannot be replaced",
      0,
    )
  }
  let invalid_range = match maximum_arity {
    Some(maximum) => maximum < minimum_arity
    None => false
  }
  if minimum_arity < 0 || invalid_range {
    raise JmesError::new(InvalidValue, "invalid custom function arity", 0)
  }
  self.functions[name] = { minimum_arity, maximum_arity, handler, }
}

///|
/// Remove a custom function. Removing an unknown name is a no-op.
pub fn Engine::unregister_function(self : Engine, name : String) -> Unit {
  self.functions.remove(name)
}

///|
fn Engine::touch_cache_entry(self : Engine, source : String) -> Unit {
  let mut found = -1
  for index, entry in self.cache_order {
    if entry == source {
      found = index
      break
    }
  }
  if found >= 0 {
    ignore(self.cache_order.remove(found))
  }
  self.cache_order.push(source)
}

///|
fn Engine::store_cache_entry(
  self : Engine,
  source : String,
  expression : Expression,
) -> Unit {
  if self.cache_capacity == 0 {
    return
  }
  if self.cache.length() >= self.cache_capacity && !self.cache.contains(source) {
    let oldest = self.cache_order.remove(0)
    self.cache.remove(oldest)
  }
  self.cache[source] = expression
  self.touch_cache_entry(source)
}

///|
/// Compile an expression or reuse the least-recently-used cached value.
pub fn Engine::compile(
  self : Engine,
  source : String,
) -> Expression raise JmesError {
  match self.cache.get(source) {
    Some(expression) => {
      self.cache_hits = self.cache_hits + 1
      self.touch_cache_entry(source)
      expression
    }
    None => {
      self.cache_misses = self.cache_misses + 1
      let expression = compile(source, limits=self.limits)
      self.store_cache_entry(source, expression)
      expression
    }
  }
}

///|
/// Compile and evaluate with this engine's limits, cache, and function registry.
pub fn Engine::search(
  self : Engine,
  source : String,
  input : Json,
) -> Json raise JmesError {
  self.compile(source).search_with_functions(input, self.functions)
}

///|
/// Evaluate one expression for multiple inputs and isolate per-input failures.
pub fn Engine::search_batch(
  self : Engine,
  source : String,
  inputs : ArrayView[Json],
) -> Array[BatchItem] raise JmesError {
  let expression = self.compile(source)
  let output : Array[BatchItem] = []
  for index, input in inputs {
    try expression.search_with_functions(input, self.functions) catch {
      error => output.push(Failure(index, error.diagnostic(source)))
    } noraise {
      value => output.push(Value(value))
    }
  }
  output
}

///|
/// Clear compiled expressions while preserving functions and counters.
pub fn Engine::clear_cache(self : Engine) -> Unit {
  self.cache.clear()
  self.cache_order.clear()
}

///|
/// Return a snapshot of cache and extension metrics.
pub fn Engine::stats(self : Engine) -> EngineStats {
  {
    cache_entries: self.cache.length(),
    cache_hits: self.cache_hits,
    cache_misses: self.cache_misses,
    custom_functions: self.functions.length(),
  }
}
