module Abstractfeld

# --- IR types and core operations ---
include("ir/types.jl")
include("ir/sexpr.jl")
include("ir/canonical.jl")
include("ir/terminterface.jl")

# --- Renderers ---
include("ir/render/latex.jl")

# --- Bridge ---
include("bridge/json.jl")

# --- E-graph rewriting engine ---
include("egraph/EGraphRewriting.jl")
using .EGraphRewriting

import Random

# --- High-level saturation API ---
include("egraph/runner.jl")
include("egraph/tensor_theory.jl")
include("egraph/numerical.jl")
include("egraph/claims.jl")

# --- Knowledge base (schema) ---
include("kb/schema.jl")

# --- Search / prompt generation + LLM prover ---
include("search/prompt.jl")
include("search/llm_prover.jl")

# --- Lean verification orchestrator ---
include("bridge/verify.jl")

# --- Validation loop (needs verify.jl types) ---
include("search/validate.jl")
include("search/retrieval.jl")
include("search/batch.jl")

# --- KB store + query (needs Verified type from verify.jl) ---
include("kb/store.jl")
include("kb/query.jl")

# Public API
export Expr, Lit, Sym, Idx, App, Bind, Ann
export IndexPos, Up, Down
export Annotation, SymmetryAnn, TypeAnn
export lit, sym, idx, app, bnd, ann, tensor
export to_sexpr, parse_sexpr
export structural_hash
export to_json, from_json
export render_latex

# E-graph rewriting
export EGraph, addexpr!, saturate!, extract!, astsize, SaturationParams
export @rule, @theory, @slots

# Saturation runner
export saturate_expr, extract_best, equivalent
export SaturationResult
export basic_algebra, scalar_rules, tensor_algebra

# Numerical pre-filter
export eval_numerical, numerical_check, numerical_fingerprint, free_syms

# Claims
export Claim, extract_simplification, extract_equivalences, make_claim, verify_claim_numerically

# Knowledge base
export KnowledgeBase, create_kb, close_kb!, insert_result!, insert_fingerprint!
export lookup_by_hash, lookup_by_level, update_level!, kb_stats
export VerifiedResult, store!, store_from_verification!
export lookup_claim, has_claim, similar_proofs, all_results

# Prompt generation
export format_prompt, render_lean_theorem_stmt

# Verification orchestrator
export VerificationResult, Verified, Rejected, VerificationTimeout
export verify, verify_trivial, render_lean_claim

# LLM prover
export generate_tactics, parse_tactic_block
export validate_proof, attempt_prove
export find_similar, find_similar_proofs
export batch_verify, BatchReport

end # module
