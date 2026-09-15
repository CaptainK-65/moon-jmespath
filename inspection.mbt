///|
/// Aggregate structural metrics for a compiled expression.
pub(all) struct PlanStats {
  nodes : Int
  max_depth : Int
  projections : Int
  functions : Int
  fields : Int
} derive(Debug, Eq, ToJson)

///|
/// A stable, serializable view of a compiled expression.
pub(all) struct QueryPlan {
  source : String
  ast : Json
  stats : PlanStats
} derive(Debug, Eq)

///|
priv struct PlanCounter {
  mut nodes : Int
  mut max_depth : Int
  mut projections : Int
  mut functions : Int
  mut fields : Int
}

///|
fn compare_operation_name(operation : CompareOp) -> String {
  match operation {
    Equal => "equal"
    NotEqual => "not_equal"
    Less => "less"
    LessOrEqual => "less_or_equal"
    Greater => "greater"
    GreaterOrEqual => "greater_or_equal"
  }
}

///|
fn ast_operation_name(ast : Ast) -> String {
  match ast {
    Identity => "identity"
    Field(_) => "field"
    Literal(_) => "literal"
    Sequence(_, _) => "sequence"
    Index(_, _) => "index"
    Slice(_, _, _, _) => "slice"
    Flatten(_) => "flatten"
    Values(_) => "values"
    Filter(_, _) => "filter"
    Projection(_, _) => "projection"
    PipeExpr(_, _) => "pipe"
    OrExpr(_, _) => "or"
    AndExpr(_, _) => "and"
    NotExpr(_) => "not"
    Compare(_, _, _) => "compare"
    MultiList(_) => "multi_list"
    MultiHash(_) => "multi_hash"
    Function(_, _) => "function"
    ExpressionRef(_) => "expression_ref"
  }
}

///|
fn optional_int_json(value : Int?) -> Json {
  match value {
    Some(value) => Json::number(value.to_double())
    None => Json::null()
  }
}

///|
fn ast_array_json(items : Array[Ast]) -> Json {
  Json::array([ for item in items => ast_to_json(item) ])
}

///|
fn ast_entries_json(entries : Array[(String, Ast)]) -> Json {
  let result : Array[Json] = []
  for entry in entries {
    let (name, value) = entry
    result.push({ "name": name, "value": ast_to_json(value) })
  }
  Json::array(result)
}

///|
fn ast_to_json(ast : Ast) -> Json {
  match ast {
    Identity => { "type": "identity" }
    Field(name) => { "type": "field", "name": name }
    Literal(value) => { "type": "literal", "value": value }
    Sequence(left, right) =>
      {
        "type": "sequence",
        "left": ast_to_json(left),
        "right": ast_to_json(right),
      }
    Index(base, index) =>
      { "type": "index", "base": ast_to_json(base), "index": index }
    Slice(base, start, stop, step) =>
      {
        "type": "slice",
        "base": ast_to_json(base),
        "start": optional_int_json(start),
        "stop": optional_int_json(stop),
        "step": optional_int_json(step),
      }
    Flatten(base) => { "type": "flatten", "base": ast_to_json(base) }
    Values(base) => { "type": "values", "base": ast_to_json(base) }
    Filter(base, predicate) =>
      {
        "type": "filter",
        "base": ast_to_json(base),
        "predicate": ast_to_json(predicate),
      }
    Projection(source, transform) =>
      {
        "type": "projection",
        "source": ast_to_json(source),
        "transform": ast_to_json(transform),
      }
    PipeExpr(left, right) =>
      { "type": "pipe", "left": ast_to_json(left), "right": ast_to_json(right) }
    OrExpr(left, right) =>
      { "type": "or", "left": ast_to_json(left), "right": ast_to_json(right) }
    AndExpr(left, right) =>
      { "type": "and", "left": ast_to_json(left), "right": ast_to_json(right) }
    NotExpr(value) => { "type": "not", "value": ast_to_json(value) }
    Compare(operation, left, right) =>
      {
        "type": "compare",
        "operation": compare_operation_name(operation),
        "left": ast_to_json(left),
        "right": ast_to_json(right),
      }
    MultiList(items) => { "type": "multi_list", "items": ast_array_json(items) }
    MultiHash(entries) =>
      { "type": "multi_hash", "entries": ast_entries_json(entries) }
    Function(name, arguments) =>
      {
        "type": "function",
        "name": name,
        "arguments": ast_array_json(arguments),
      }
    ExpressionRef(value) =>
      { "type": "expression_ref", "value": ast_to_json(value) }
  }
}

///|
fn PlanCounter::visit(self : PlanCounter, ast : Ast, depth : Int) -> Unit {
  self.nodes = self.nodes + 1
  if depth > self.max_depth {
    self.max_depth = depth
  }
  match ast {
    Field(_) => self.fields = self.fields + 1
    Projection(source, transform) => {
      self.projections = self.projections + 1
      self.visit(source, depth + 1)
      self.visit(transform, depth + 1)
    }
    Function(_, arguments) => {
      self.functions = self.functions + 1
      for argument in arguments {
        self.visit(argument, depth + 1)
      }
    }
    Sequence(left, right)
    | PipeExpr(left, right)
    | OrExpr(left, right)
    | AndExpr(left, right) => {
      self.visit(left, depth + 1)
      self.visit(right, depth + 1)
    }
    Compare(_, left, right) | Filter(left, right) => {
      self.visit(left, depth + 1)
      self.visit(right, depth + 1)
    }
    Index(base, _)
    | Slice(base, _, _, _)
    | Flatten(base)
    | Values(base)
    | NotExpr(base)
    | ExpressionRef(base) => self.visit(base, depth + 1)
    MultiList(items) =>
      for item in items {
        self.visit(item, depth + 1)
      }
    MultiHash(entries) =>
      for entry in entries {
        self.visit(entry.1, depth + 1)
      }
    Identity | Literal(_) => ()
  }
}

///|
fn collect_plan_stats(ast : Ast) -> PlanStats {
  let counter : PlanCounter = {
    nodes: 0,
    max_depth: 0,
    projections: 0,
    functions: 0,
    fields: 0,
  }
  counter.visit(ast, 1)
  {
    nodes: counter.nodes,
    max_depth: counter.max_depth,
    projections: counter.projections,
    functions: counter.functions,
    fields: counter.fields,
  }
}

///|
/// Return the stable JSON representation of the internal syntax tree.
pub fn Expression::ast_json(self : Expression) -> Json {
  ast_to_json(self.ast)
}

///|
/// Build a serializable plan without exposing private AST constructors.
pub fn Expression::explain(self : Expression) -> QueryPlan {
  {
    source: self.source,
    ast: self.ast_json(),
    stats: collect_plan_stats(self.ast),
  }
}

///|
pub fn QueryPlan::to_json(self : QueryPlan) -> Json {
  { "source": self.source, "ast": self.ast, "stats": self.stats }
}
