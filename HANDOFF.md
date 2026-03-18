# Handoff — Session 2026-03-18 (evening)

## Project state

**All 26 planned issues closed.** 190 Julia tests pass. Lean builds clean (1215 jobs). 22 axiom-free Lean theorems. 16 L4-verified results seeded in DuckDB. The full verification pipeline works end-to-end.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ IR (src/ir/)                                              │
│ 6 immutable types: Lit, Sym, Idx, App, Bind, Ann         │
│ S-expr serialize, structural hash, LaTeX, JSON bridge     │
│ TermInterface 2.0 protocol (isexpr + iscall + maketerm)  │
└─────────────┬────────────────────────────────────────────┘
              │
    ┌─────────▼──────────┐     ┌────────────────────────────┐
    │ E-graph (src/egraph/)│     │ Lean4 (lean/)              │
    │ Extracted from       │     │ IR mirror: Expr inductive  │
    │ Metatheory.jl v3     │     │ Bridge: parseExpr/exprToJson│
    │ ~4k LOC, in-tree     │     │ eval: Expr → AlternatingMap│
    │ @rule/@theory DSL    │     │ 22 axiom-free theorems     │
    │ saturate!/extract!   │     │ Mathlib v4.29.0-rc6        │
    └─────────┬────────────┘     └──────────┬─────────────────┘
              │ Claims                       │ Verified/Rejected
    ┌─────────▼──────────────────────────────▼─────────────────┐
    │ Search loop (src/search/)                                 │
    │ prompt.jl: format_prompt (structured LLM prompt)          │
    │ llm_prover.jl: generate_tactics via Anthropic API         │
    │ validate.jl: attempt_prove (LLM → Lean → error → retry)  │
    │ retrieval.jl: find_similar (RAG from KB)                  │
    │ batch.jl: batch_verify (full flywheel pipeline)           │
    └─────────────────────────┬────────────────────────────────┘
                              │
    ┌─────────────────────────▼────────────────────────────────┐
    │ Knowledge Base (src/kb/)                                  │
    │ DuckDB: results + fingerprints tables                     │
    │ Verification lattice: L0 → L1 → L2 → L3 → L4           │
    │ Hash dedup, level upgrade, numerical fingerprinting       │
    │ 16 L4 results seeded in abstractfeld.duckdb               │
    └──────────────────────────────────────────────────────────┘
```

## File map

```
Project.toml                          — deps: JSON3, TermInterface 2.0, SHA, TimerOutputs, HTTP, DuckDB, Random
src/Abstractfeld.jl                   — top-level module, preprocess hooks for e-graph

src/ir/types.jl                       — IR: Lit, Sym, Idx, App, Bind, Ann
src/ir/sexpr.jl                       — S-expression serialize/parse
src/ir/canonical.jl                   — structural hashing (SHA-256)
src/ir/terminterface.jl               — TermInterface 2.0 (isexpr, iscall, head, operation, arguments, maketerm)
src/ir/render/latex.jl                — LaTeX renderer
src/bridge/json.jl                    — JSON bridge (Julia↔Lean wire format)
src/bridge/verify.jl                  — Lean verification orchestrator (temp file + lake env lean + timeout)

src/egraph/EGraphRewriting.jl         — top-level e-graph module
src/egraph/vecexpr.jl                 — VecExpr packed e-node representation
src/egraph/optbuffer.jl               — optimized match result buffer
src/egraph/unionfind.jl               — Union-Find data structure
src/egraph/uniquequeue.jl             — pending operations queue
src/egraph/egraph.jl                  — EGraph, EClass, add!, union!, rebuild!, addexpr!
src/egraph/patterns.jl                — Pat type for rule patterns
src/egraph/rules.jl                   — RewriteRule, Theory
src/egraph/ematch.jl                  — e-matching compiler (generates match closures)
src/egraph/match.jl                   — classical term matching compiler
src/egraph/syntax.jl                  — @rule, @theory, @slots macros
src/egraph/extract.jl                 — cost-based extraction (astsize)
src/egraph/schedulers.jl              — BackoffScheduler, SimpleScheduler
src/egraph/saturate.jl                — saturate! main loop
src/egraph/runner.jl                  — saturate_expr, extract_best, equivalent
src/egraph/tensor_theory.jl           — basic_algebra (8 rules) + scalar_rules (3 rules)
src/egraph/numerical.jl               — eval_numerical, numerical_check, numerical_fingerprint
src/egraph/claims.jl                  — Claim struct, extract_simplification, extract_equivalences

src/search/prompt.jl                  — format_prompt, render_lean_theorem_stmt
src/search/llm_prover.jl              — generate_tactics, parse_tactic_block, call_anthropic
src/search/validate.jl                — validate_proof, attempt_prove (compiler-guided repair)
src/search/retrieval.jl               — find_similar, find_similar_proofs (RAG)
src/search/batch.jl                   — batch_verify (full pipeline per claim)

src/kb/schema.jl                      — DuckDB tables, create_kb, insert_result!, kb_stats
src/kb/store.jl                       — VerifiedResult, store! (dedup + level upgrade)
src/kb/query.jl                       — lookup_claim, has_claim, similar_proofs, all_results

test/runtests.jl                      — harness (190 tests)
test/test_ir.jl                       — IR type tests
test/test_sexpr.jl                    — S-expression round-trip
test/test_canonical.jl                — structural hash
test/test_json.jl                     — JSON round-trip
test/test_latex.jl                    — LaTeX renderer
test/test_terminterface.jl            — TermInterface protocol
test/test_roundtrip.jl                — Julia↔Lean JSON round-trip (15 expressions)
test/test_egraph.jl                   — e-graph saturation + numerical pre-filter (23 tests)
test/test_pipeline.jl                 — end-to-end pipeline integration (27 tests)

lean/lakefile.lean                    — Lake config (Mathlib dep + roundtrip exe)
lean/lean-toolchain                   — v4.29.0-rc6
lean/Abstractfeld.lean                — root import
lean/Abstractfeld/IR/Expr.lean        — IR mirror inductive type
lean/Abstractfeld/Bridge.lean         — imports Bridge/Parse
lean/Abstractfeld/Bridge/Parse.lean   — parseExpr, exprToJson (JSON ↔ Lean Expr)
lean/Abstractfeld/Bridge/RoundTrip.lean — stdin→parse→serialize→stdout executable
lean/Abstractfeld/Tensor.lean         — imports Interpret + Identities + Verified
lean/Abstractfeld/Tensor/Interpret.lean — eval : Expr → AlternatingMap, Env, simp lemmas
lean/Abstractfeld/Tensor/Identities.lean — 6 core theorems (antisym, block_sym, swap_cancel, etc.)
lean/Abstractfeld/Tensor/Verified.lean — 19 theorems (rank 2-4, eval-level, 3 discovered by e-graph)

abstractfeld.duckdb                   — seeded KB with 16 L4 results
```

## Key design decisions

1. **E-graph extracted from Metatheory.jl v3** (`ale/3.0` branch, MIT license). Not a dependency — copied in-tree at `src/egraph/`. The unreleased v3 uses TermInterface 2.0; the released v2.0.2 doesn't. We expect to diverge heavily from upstream.

2. **Preprocessing bridge for rule matching**: `EGraphRewriting.preprocess(::App)` remaps `:neg` → `:-` so Julia's `@rule -(~a)` patterns match our IR. `preprocess(::Lit)` unwraps to raw `Rational{BigInt}` so `0` in rules matches `lit(0)` in the e-graph. On extraction, `maketerm` remaps `:-` → `:neg` (arity 1) back.

3. **Lean verification via temp files**: `verify()` writes a `.lean` file into the `lean/` project dir, runs `lake env lean <file>`, parses exit code. Verified = exit 0, Rejected = error output, Timeout = killed after deadline.

4. **LLM prover is pluggable**: `attempt_prove` calls `generate_tactics` → `validate_proof` → error feedback → retry. `generate_tactics` calls the Anthropic API. The API key is not set — all LLM tests gracefully return `nothing`/`Rejected`.

## Known issues / limitations

1. **Directed rules with constants partially work**: `a + 0 --> a` and `a + (-a) --> 0` now fire correctly after the preprocessing fix. But `0 * a --> 0` may have issues because `*` in Julia is `Base.:*` (function) vs our `:*` (symbol) — same hash-pair mechanism as `+`, should work but not tested with scalar rules specifically.

2. **E-graph doesn't know about tensor indices**: Rules like `a + b == b + a` are generic. There's no rule that says "R_{abdc} = -R_{abcd}" because that requires index-aware pattern matching (knowing that indices [a,b,d,c] are a swap of [a,b,c,d]). The Lean theorems prove this, but the e-graph can't discover it autonomously yet.

3. **`@rule` macro runs at compile time**: The `ematch_compile` function generates closures with module-qualified references (`EGraphRewriting.EGraph`, etc.) to work across module boundaries. Any new VecExpr helper used in generated code needs `$(func_name)` interpolation, not bare references.

4. **DuckDB deprecation warnings**: `toDataFrame` triggers deprecation notices. Cosmetic, doesn't affect correctness.

5. **Lean `Verified.lean` theorems use `sorry`-free proofs**: All 22 theorems depend only on `propext`, `Classical.choice`, `Quot.sound`. No custom axioms. Checked via `#print axioms`.

## What the e-graph CAN do (validated)

With `tensor_algebra()` (11 rules), the e-graph discovers:
- All permutations of `a+b+c` are equivalent (commutativity + associativity)
- `-(a+b) = (-a)+(-b)` (negation distribution)
- `a+(-a) = (-a)+a = 0` (cancellation merges with zero)
- `-(-a) = a` (double negation, extracts correctly)
- **Discovered (not in rules)**: `(a+b)+(-b) = a`, `(a+b)+(-(a+b)) = 0`, `-(-(a+b)) = a+b`

All discovered identities were numerically verified (1000 points) and formally proven in Lean.

## What to do next

### Priority 1: Integralis integration

The sister project `../Integralis` has 50k+ integral formulas at L2 (numerically verified). Adapting the Abstractfeld flywheel to upgrade them to L4:

**IR bridge** (~50 lines): Map Integralis `IntExpr` (Literal/Sym/Call with ops `:add`, `:mul`, `:neg`, `:pow`, `:sin`, etc.) to Abstractfeld `Expr` (Lit/Sym/App with ops `:+`, `:*`, `:neg`, `:^`, `:sin`, etc.). Mechanical symbol remapping.

**Lean theorem template**: For an integral `∫f(x)dx = F(x)`, the Lean statement is:
```lean
theorem integral_identity : ∀ x, HasDerivAt F f x
```
Using Mathlib's `HasDerivAt` / `deriv` / `integral_eq_of_hasDerivAt` API.

**Import pipeline**: Read from Integralis DuckDB → create Claims → numerical verify → LLM tactic gen → Lean verify → store at L4.

**Key challenge**: Mathlib's calculus API (`HasDerivAt` proofs) is more complex than the algebraic `AlternatingMap` proofs we've done. The LLM + compiler-guided repair loop should help, but expect lower success rate initially.

**Estimated effort**: 1-2 sessions for bridge + template + import. Lean proof generation will be iterative.

### Priority 2: Index-aware tensor rules

To make the e-graph discover tensor-specific identities like `R_{abcd} + R_{abdc} = 0`:
- Need permutation-tracking patterns in the e-graph
- Or: encode index positions in the operation symbol (e.g., `:tensor_abcd` vs `:tensor_abdc`)
- Or: use dynamic rules that inspect index children

### Priority 3: Run batch_verify with API

Set `ANTHROPIC_API_KEY` and run `batch_verify` on:
- The 16 seeded claims (should be 100% cached)
- New claims generated from TensorGR.jl rule set
- Imported Integralis claims

### Priority 4: E-graph cleanup

The extracted Metatheory.jl code is ~4k LOC. Can likely trim to ~2k:
- Remove `Rewriters.jl` (not used — we use e-graph mode only)
- Remove `Library.jl` (built-in rules we don't need)
- Remove `@capture`, `@match` macros
- Simplify `Syntax.jl` (remove Expr-specific codepaths)
- Add path compression to UnionFind (commented out, free speedup)

## Session git log

```
edc9909 Fix e-graph impedance mismatch, discover and verify 3 new identities
74e68c3 Flywheel: 16 Lean-verified tensor identities seeded into KB
3ce7332 LLM prover + tactic validation + KB store with provenance
5eff765 Claim-to-prompt formatter + Lean verification orchestrator
3edcc24 Claims extractor + DuckDB knowledge base
b8c6d75 Saturation runner + numerical pre-filter + tensor theory
4cc2ee1 E-graph engine: extract Metatheory.jl v3 core, adapt for Abstractfeld IR
46379ae M1 bridge + verification kernel: Julia↔Lean round-trip + tensor identity theorems
```
