# Architecture

MoonJMES keeps the public API small and separates four responsibilities inside
one MoonBit package:

1. `lexer.mbt` converts UTF-16 source text into source-aware tokens and decodes
   quoted identifiers, raw strings, and JSON literals.
2. `parser.mbt` applies precedence rules and creates a projection-aware AST.
   Projection transforms are extended when a suffix follows `[*]`, `[]`, or a
   filter, preserving JMESPath's element-wise semantics.
3. `evaluator.mbt` walks standard MoonBit `Json` values. It owns truthiness,
   indexing, slicing, comparison, flattening, projection, and resource-budget
   accounting.
4. `functions.mbt` owns arity/type validation and the standard function
   registry, including expression-reference functions such as `map` and
   `sort_by`.

`expression.mbt` is the public facade. `compile` performs lexing and parsing
once; `Expression::search` may then reuse the AST across multiple JSON values.
The one-shot `search` helper composes those calls.

## Error boundary

All public failures use `JmesError::Fault(ErrorKind, String, Int)`. Syntax
errors carry their UTF-16 source offset. Data-only errors use offset zero.
Callers can branch on `ErrorKind` without parsing human-readable text.

## Resource boundary

`Limits` provides four independent safeguards:

- `max_expression_length` is checked before tokenization;
- `max_ast_nodes` is checked as nodes are constructed;
- `max_depth` is checked on evaluator recursion;
- `max_steps` bounds total evaluator node visits.

The default values are finite. Callers handling untrusted expressions may pass
stricter limits without changing query semantics.

## Portability

The core library only imports `moonbitlang/core/json`. It performs no file,
network, process, clock, or platform-specific I/O, so the same implementation
is checked and tested on Wasm, Wasm GC, JavaScript, and Native.

