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

# Public API
export Expr, Lit, Sym, Idx, App, Bind, Ann
export IndexPos, Up, Down
export Annotation, SymmetryAnn, TypeAnn
export lit, sym, idx, app, bnd, ann, tensor
export to_sexpr, parse_sexpr
export structural_hash
export to_json, from_json
export render_latex

end # module
