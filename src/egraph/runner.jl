"""
High-level saturation API for Abstractfeld IR expressions.
Wraps the core e-graph engine with tensor-specific theory and convenience functions.
"""

using ..EGraphRewriting: EGraph, addexpr!, saturate!, extract!, astsize, SaturationParams,
    in_same_class, rebuild!, SaturationReport

"""
    SaturationResult

Result of running equality saturation on an IR expression.
"""
struct SaturationResult
    egraph::EGraph
    root::UInt64
    num_eclasses::Int
    num_enodes::Int
    reason::Symbol
    iterations::Int
    elapsed_ns::UInt64
end

function Base.show(io::IO, r::SaturationResult)
    print(io, "SaturationResult(", r.reason, ", ", r.iterations, " iters, ",
          r.num_eclasses, " eclasses, ", r.num_enodes, " enodes)")
end

"""
    saturate_expr(expr::Expr, theory; timeout=8, eclasslimit=5000, enodelimit=15000) → SaturationResult

Build an e-graph from `expr`, run equality saturation with the given theory, and return results.
"""
function saturate_expr(expr, theory;
        timeout::Int=8, eclasslimit::Int=5000, enodelimit::Int=15000,
        timelimit::UInt64=UInt64(0))
    g = EGraph(expr)
    params = SaturationParams(;
        timeout, eclasslimit, enodelimit, timelimit,
        timer=false)
    start = time_ns()
    report = saturate!(g, theory, params)
    elapsed = time_ns() - start
    SaturationResult(
        g, g.root,
        length(g.classes), length(g.memo),
        something(report.reason, :unknown),
        report.iterations,
        elapsed)
end

"""
    extract_best(result::SaturationResult) → Expr

Extract the smallest equivalent expression from a saturation result.
"""
extract_best(result::SaturationResult) = extract!(result.egraph, astsize)

"""
    equivalent(expr1, expr2, theory; timeout=8) → Bool

Check whether two expressions are equivalent under the given theory
by adding both to a fresh e-graph and saturating.
"""
function equivalent(expr1, expr2, theory; timeout::Int=8)
    g = EGraph(expr1)
    id2 = addexpr!(g, expr2)
    rebuild!(g)
    saturate!(g, theory, SaturationParams(; timeout, timer=false))
    in_same_class(g, g.root, id2)
end
