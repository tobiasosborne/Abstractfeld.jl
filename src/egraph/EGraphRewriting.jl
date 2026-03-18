"""
    EGraphRewriting

E-graph equality saturation engine, extracted from Metatheory.jl v3.0 (ale/3.0).
Original authors: Alessandro Cheli et al. (MIT License)
Adapted for Abstractfeld.jl — divergence from upstream is expected.
"""
module EGraphRewriting

using TermInterface: isexpr, iscall, head, operation, children, arguments, arity, maketerm
using TimerOutputs

@inline alwaystrue(x...) = true

function to_expr end

Base.@inline maybe_quote_operation(x::Union{Function,DataType,UnionAll}) = nameof(x)
Base.@inline maybe_quote_operation(x) = x

include("vecexpr.jl")
using .VecExprModule

include("optbuffer.jl")
export OptBuffer

const UNDEF_ID_VEC = Vector{Id}(undef, 0)

include("utils.jl")

include("patterns.jl")
using .Patterns

include("match.jl")
export match_compile

include("ematch.jl")
export ematch_compile

include("rules.jl")
using .Rules

include("syntax.jl")
using .Syntax

# EGraph core
include("unionfind.jl")
export UnionFind

include("uniquequeue.jl")

include("egraph.jl")
export Id, EClass, EGraph, find, lookup, addexpr!, rebuild!, in_same_class, has_constant, get_constant, lookup_pat

include("extract.jl")
export extract!, astsize, astsize_inv

include("schedulers.jl")
export Schedulers
using .Schedulers

include("saturate.jl")
export SaturationParams, saturate!

# Re-export key symbols
export @rule, @theory, @slots, @capture
export RewriteRule, DirectedRule, EqualityRule, UnequalRule, DynamicRule
export -->, Theory
export Pat

end # module
