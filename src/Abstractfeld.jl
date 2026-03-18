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

end # module
