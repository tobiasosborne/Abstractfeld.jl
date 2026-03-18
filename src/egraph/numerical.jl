"""
Numerical pre-filter (L2 verification).
Evaluates candidate identities at random rational points to cheaply reject
false claims before expensive Lean verification.
"""

using SHA: sha256

"""
    eval_numerical(expr::Expr, bindings::Dict{Symbol,Rational{BigInt}}) → Union{Rational{BigInt}, Nothing}

Evaluate an IR expression numerically with the given variable bindings.
Returns `nothing` for unevaluable expressions.
"""
function eval_numerical(e::Lit, bindings::Dict{Symbol,Rational{BigInt}})
    e.val
end

function eval_numerical(e::Sym, bindings::Dict{Symbol,Rational{BigInt}})
    get(bindings, e.name, nothing)
end

function eval_numerical(e::Idx, bindings::Dict{Symbol,Rational{BigInt}})
    get(bindings, e.name, nothing)
end

function eval_numerical(e::App, bindings::Dict{Symbol,Rational{BigInt}})
    args = [eval_numerical(a, bindings) for a in e.args]
    any(isnothing, args) && return nothing
    op = e.op
    if op === :+ && length(args) == 2
        args[1] + args[2]
    elseif op === :- && length(args) == 2
        args[1] - args[2]
    elseif op === :* && length(args) == 2
        args[1] * args[2]
    elseif op === :neg && length(args) == 1
        -args[1]
    elseif op === :/ && length(args) == 2 && !iszero(args[2])
        args[1] // args[2]
    elseif op === :+ && length(args) > 2
        sum(args)
    elseif op === :* && length(args) > 2
        prod(args)
    else
        nothing  # unknown operation
    end
end

function eval_numerical(e::Bind, bindings::Dict{Symbol,Rational{BigInt}})
    nothing  # integrals etc. not evaluable numerically
end

function eval_numerical(e::Ann, bindings::Dict{Symbol,Rational{BigInt}})
    eval_numerical(e.expr, bindings)
end

"""
    free_syms(expr::Expr) → Set{Symbol}

Collect all free symbol names in an expression.
"""
function free_syms(e::Lit)
    Set{Symbol}()
end

function free_syms(e::Sym)
    Set{Symbol}([e.name])
end

function free_syms(e::Idx)
    Set{Symbol}([e.name])
end

function free_syms(e::App)
    reduce(union!, free_syms.(e.args); init=Set{Symbol}())
end

function free_syms(e::Bind)
    s = union(free_syms(e.var), free_syms(e.body))
    for m in e.metadata
        union!(s, free_syms(m))
    end
    s
end

function free_syms(e::Ann)
    free_syms(e.expr)
end

"""
    random_rationals(vars::Set{Symbol}; rng=nothing) → Dict{Symbol,Rational{BigInt}}

Generate random small rational bindings for a set of variables.
"""
function random_rationals(vars; rng=Random.default_rng())
    Dict{Symbol,Rational{BigInt}}(
        v => Rational{BigInt}(rand(rng, -10:10), rand(rng, 1:10))
        for v in vars
    )
end

"""
    numerical_check(lhs::Expr, rhs::Expr; n_points=100) → Bool

Check whether `lhs == rhs` holds at `n_points` random rational evaluation points.
Returns `true` if all evaluations match (suggesting the identity is valid),
`false` if any mismatch is found (proving the identity is false).
"""
function numerical_check(lhs, rhs; n_points::Int=100)
    vars = union(free_syms(lhs), free_syms(rhs))
    isempty(vars) && return eval_numerical(lhs, Dict{Symbol,Rational{BigInt}}()) ==
                            eval_numerical(rhs, Dict{Symbol,Rational{BigInt}}())
    rng = Random.MersenneTwister(42)  # deterministic seed
    for _ in 1:n_points
        bindings = random_rationals(vars; rng)
        l = eval_numerical(lhs, bindings)
        r = eval_numerical(rhs, bindings)
        isnothing(l) || isnothing(r) && continue
        l != r && return false
    end
    true
end

"""
    numerical_fingerprint(expr::Expr; n_points=32) → Vector{UInt8}

Compute a deterministic numerical fingerprint for an expression.
The seed is derived from the structural hash, so the same expression
always produces the same fingerprint across sessions.
"""
function numerical_fingerprint(expr; n_points::Int=32)
    vars = free_syms(expr)
    seed = reinterpret(UInt64, sha256(to_sexpr(expr)))[1]
    rng = Random.MersenneTwister(seed)
    vals = Rational{BigInt}[]
    for _ in 1:n_points
        bindings = random_rationals(vars; rng)
        v = eval_numerical(expr, bindings)
        push!(vals, something(v, Rational{BigInt}(0)))
    end
    sha256(join(string.(vals), ","))
end
