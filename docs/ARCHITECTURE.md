# Architecture

MoonJMES separates reusable query semantics from consumers and presentation.

1. `lexer.mbt` records source offsets and decodes identifiers, raw strings, and
   JSON literals. `parser.mbt` builds the private projection-aware AST.
2. `evaluator.mbt` implements traversal, truthiness, projections, comparison,
   resource accounting, and dispatch into `functions.mbt`.
3. `expression.mbt` exposes the opaque compiled-expression boundary. `api.mbt`
   defines public limits and structured error values; `diagnostic.mbt` converts
   offsets into line/column spans and excerpts.
4. `engine.mbt` adds LRU compilation caching, custom functions, isolated batch
   evaluation, and metrics without expanding the core expression type.
5. `inspection.mbt`, `analysis.mbt`, and `trace.mbt` provide JSON AST export,
   query plans, static inventories/findings, and bounded post-order traces.
6. `ndjson.mbt`, `pipeline.mbt`, and `catalog.mbt` provide reusable data-tooling
   primitives above the same compiler and evaluator.
7. `playground/model` converts all results into a stable JSON response.
   `playground/app` is the thin JS export boundary, while `playground/site`
   contains presentation-only HTML, CSS, and JavaScript.

The core package performs no file, network, process, clock, DOM, or database
I/O. It imports only MoonBit core packages, so one implementation is checked
and tested on Wasm, Wasm GC, JavaScript, and Native. Tooling that needs file I/O
lives in standalone `.mbtx` scripts and is not part of the published library.

## Public boundaries

`Expression`, `Engine`, `Pipeline`, and `QueryCatalog` are opaque. Callers use
constructors and methods rather than depending on storage layout. The formal
declarations in `v2_contract.mbt` and compile-time contract tests protect this
surface from accidental drift.

## Safety boundaries

- `Limits` bounds parser and evaluator work.
- `TraceOptions` bounds event count and preview size.
- `Engine` bounds cache capacity and validates custom function names/arities.
- NDJSON processing reports failures with one-based line numbers and can either
  continue or stop early.
- Batch and catalog operations preserve per-item failures instead of discarding
  successful results.

## Release boundaries

Generated compliance data, compiler output, packaged archives, and assembled
Playground files are reproducible but not treated as production source. CI
enforces at least 3,500 physical lines of non-test, non-generated MoonBit source
and rebuilds every release artifact from a clean checkout.
