# Equivalence claim extraction from saturated e-graphs.
# After saturation, we extract pairs (lhs, rhs) proven equivalent,
# which become candidates for formal verification in Lean.

using ..EGraphRewriting: EGraph, extract!, astsize, in_same_class, addexpr!, rebuild!

"""
    Claim

An equivalence claim extracted from e-graph saturation.
"""
struct Claim
    lhs::Expr
    rhs::Expr
    rules_used::Vector{Symbol}
    confidence::Float64
end

function Base.show(io::IO, c::Claim)
    print(io, "Claim(", to_sexpr(c.lhs), " = ", to_sexpr(c.rhs), ")")
end

"""
    extract_simplification(result::SaturationResult) → Union{Claim, Nothing}

Extract the "original = simplified" claim from a saturation result.
Returns `nothing` if the expression didn't simplify.
"""
function extract_simplification(result::SaturationResult)
    g = result.egraph
    simplified = extract!(g, astsize, result.root)
    # Reconstruct the original from the root's largest expression
    largest = extract!(g, EGraphRewriting.astsize_inv, result.root)
    simplified == largest && return nothing
    Claim(largest, simplified, _active_rules(result), 1.0)
end

"""
    extract_equivalences(result::SaturationResult, exprs::Vector) → Vector{Claim}

Given a set of expressions that were added to the e-graph before saturation,
find all pairs that ended up in the same equivalence class.
"""
function extract_equivalences(result::SaturationResult, exprs::Vector)
    g = result.egraph
    ids = [addexpr!(g, e) for e in exprs]
    rebuild!(g)

    claims = Claim[]
    rules = _active_rules(result)
    for i in 1:length(exprs)
        for j in (i+1):length(exprs)
            if in_same_class(g, ids[i], ids[j])
                push!(claims, Claim(exprs[i], exprs[j], rules, 1.0))
            end
        end
    end
    claims
end

"""
    make_claim(lhs, rhs; rules=Symbol[], confidence=1.0) → Claim

Manually construct a claim.
"""
make_claim(lhs, rhs; rules::Vector{Symbol}=Symbol[], confidence::Float64=1.0) =
    Claim(lhs, rhs, rules, confidence)

"""
    verify_claim_numerically(claim::Claim; n_points=100) → Bool

Check a claim with the numerical pre-filter (L2 verification).
"""
verify_claim_numerically(claim::Claim; n_points::Int=100) =
    numerical_check(claim.lhs, claim.rhs; n_points)

# Internal: infer which rule categories were active during saturation.
# Since Metatheory doesn't emit proof traces, we infer from the result.
function _active_rules(result::SaturationResult)
    rules = Symbol[]
    result.num_enodes > result.num_eclasses && push!(rules, :rewriting)
    result.reason == :saturated && push!(rules, :saturated)
    rules
end
