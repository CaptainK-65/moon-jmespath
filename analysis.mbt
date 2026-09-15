///|
/// Severity assigned to a static query-analysis finding.
pub(all) enum AnalysisSeverity {
  Information
  Warning
} derive(Debug, Eq)

///|
/// One actionable finding produced without evaluating input data.
pub(all) struct AnalysisFinding {
  code : String
  severity : AnalysisSeverity
  message : String
} derive(Debug, Eq)

///|
/// Thresholds used to classify query complexity.
pub(all) struct AnalysisOptions {
  node_warning_threshold : Int
  depth_warning_threshold : Int
  projection_warning_threshold : Int
} derive(Debug, Eq)

///|
/// Static inventory and findings for a compiled expression.
pub(all) struct ExpressionAnalysis {
  source : String
  stats : PlanStats
  fields : Array[String]
  functions : Array[String]
  findings : Array[AnalysisFinding]
  uses_filters : Bool
  uses_expression_references : Bool
} derive(Debug, Eq)

///|
priv struct AnalysisCollector {
  fields : Array[String]
  functions : Array[String]
  mut uses_filters : Bool
  mut uses_expression_references : Bool
}

///|
pub fn AnalysisOptions::default() -> AnalysisOptions {
  {
    node_warning_threshold: 128,
    depth_warning_threshold: 24,
    projection_warning_threshold: 12,
  }
}

///|
fn add_unique(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn AnalysisCollector::visit(self : AnalysisCollector, ast : Ast) -> Unit {
  match ast {
    Field(name) => add_unique(self.fields, name)
    Function(name, arguments) => {
      add_unique(self.functions, name)
      for argument in arguments {
        self.visit(argument)
      }
    }
    Filter(base, predicate) => {
      self.uses_filters = true
      self.visit(base)
      self.visit(predicate)
    }
    ExpressionRef(value) => {
      self.uses_expression_references = true
      self.visit(value)
    }
    Sequence(left, right)
    | Projection(left, right)
    | PipeExpr(left, right)
    | OrExpr(left, right)
    | AndExpr(left, right)
    | Compare(_, left, right) => {
      self.visit(left)
      self.visit(right)
    }
    Index(base, _)
    | Slice(base, _, _, _)
    | Flatten(base)
    | Values(base)
    | NotExpr(base) => self.visit(base)
    MultiList(items) =>
      for item in items {
        self.visit(item)
      }
    MultiHash(entries) =>
      for entry in entries {
        self.visit(entry.1)
      }
    Identity | Literal(_) => ()
  }
}

///|
fn finding(
  code : String,
  severity : AnalysisSeverity,
  message : String,
) -> AnalysisFinding {
  { code, severity, message, }
}

///|
fn complexity_findings(
  stats : PlanStats,
  options : AnalysisOptions,
) -> Array[AnalysisFinding] {
  let findings : Array[AnalysisFinding] = []
  if stats.nodes > options.node_warning_threshold {
    findings.push(
      finding(
        "high_node_count",
        Warning,
        "query has \{stats.nodes} nodes; consider splitting it into a pipeline",
      ),
    )
  }
  if stats.max_depth > options.depth_warning_threshold {
    findings.push(
      finding(
        "high_nesting_depth",
        Warning,
        "query nesting depth \{stats.max_depth} exceeds the configured analysis threshold",
      ),
    )
  }
  if stats.projections > options.projection_warning_threshold {
    findings.push(
      finding(
        "projection_heavy",
        Warning,
        "query uses \{stats.projections} projections and may expand large inputs",
      ),
    )
  }
  findings
}

///|
fn portability_findings(functions : Array[String]) -> Array[AnalysisFinding] {
  let findings : Array[AnalysisFinding] = []
  for name in functions {
    if !is_standard_function(name) {
      findings.push(
        finding(
          "custom_function",
          Information,
          "function \{name} requires a compatible Engine registration",
        ),
      )
    }
  }
  findings
}

///|
fn append_findings(
  destination : Array[AnalysisFinding],
  source : Array[AnalysisFinding],
) -> Unit {
  for item in source {
    destination.push(item)
  }
}

///|
/// Analyze a compiled expression without inspecting or evaluating input data.
pub fn Expression::analyze(
  self : Expression,
  options? : AnalysisOptions = AnalysisOptions::default(),
) -> ExpressionAnalysis {
  let collector : AnalysisCollector = {
    fields: [],
    functions: [],
    uses_filters: false,
    uses_expression_references: false,
  }
  collector.visit(self.ast)
  collector.fields.sort_by((left, right) => left.lexical_compare(right))
  collector.functions.sort_by((left, right) => left.lexical_compare(right))
  let stats = collect_plan_stats(self.ast)
  let findings = complexity_findings(stats, options)
  append_findings(findings, portability_findings(collector.functions))
  {
    source: self.source,
    stats,
    fields: collector.fields,
    functions: collector.functions,
    findings,
    uses_filters: collector.uses_filters,
    uses_expression_references: collector.uses_expression_references,
  }
}

///|
fn severity_name(severity : AnalysisSeverity) -> String {
  match severity {
    Information => "information"
    Warning => "warning"
  }
}

///|
fn finding_to_json(value : AnalysisFinding) -> Json {
  {
    "code": value.code,
    "severity": severity_name(value.severity),
    "message": value.message,
  }
}

///|
pub fn ExpressionAnalysis::to_json(self : ExpressionAnalysis) -> Json {
  {
    "source": self.source,
    "stats": self.stats,
    "fields": self.fields,
    "functions": self.functions,
    "findings": Json::array(
      [
        for value in self.findings => finding_to_json(value)
      ],
    ),
    "uses_filters": self.uses_filters,
    "uses_expression_references": self.uses_expression_references,
  }
}
