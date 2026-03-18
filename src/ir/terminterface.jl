"""
    TermInterface.jl protocol implementation for IR types.

This enables Metatheory.jl e-graph rewriting and SymbolicUtils.jl interop
on Abstractfeld IR types without coupling to their specific representations.
"""

using TermInterface

# --- App nodes are the primary "call" form ---

TermInterface.iscall(::Type{App}) = true
TermInterface.iscall(::App) = true

TermInterface.head(e::App) = e.op
TermInterface.children(e::App) = e.args
TermInterface.operation(e::App) = e.op
TermInterface.arguments(e::App) = e.args

function TermInterface.maketerm(::Type{App}, head, children; metadata=nothing)
    App(head, collect(Expr, children))
end

# --- Bind nodes are also callable (binder is the "operation") ---

TermInterface.iscall(::Type{Bind}) = true
TermInterface.iscall(::Bind) = true

TermInterface.head(e::Bind) = e.binder
TermInterface.children(e::Bind) = Expr[e.var, e.body, e.metadata...]
TermInterface.operation(e::Bind) = e.binder
TermInterface.arguments(e::Bind) = Expr[e.var, e.body, e.metadata...]

function TermInterface.maketerm(::Type{Bind}, head, children; metadata=nothing)
    length(children) >= 2 || error("Bind requires at least var and body")
    Bind(head, children[1], children[2], Expr[children[i] for i in 3:length(children)])
end

# --- Leaf nodes ---

TermInterface.iscall(::Type{Lit}) = false
TermInterface.iscall(::Lit) = false
TermInterface.iscall(::Type{Sym}) = false
TermInterface.iscall(::Sym) = false
TermInterface.iscall(::Type{Idx}) = false
TermInterface.iscall(::Idx) = false

# --- Ann delegates to inner expr ---

TermInterface.iscall(::Type{Ann}) = true
TermInterface.iscall(::Ann) = true
TermInterface.head(e::Ann) = :ann
TermInterface.children(e::Ann) = Expr[e.expr]
TermInterface.operation(e::Ann) = :ann
TermInterface.arguments(e::Ann) = Expr[e.expr]

function TermInterface.maketerm(::Type{Ann}, head, children; metadata=nothing)
    # Preserve the annotation from the original when reconstructing
    # This is a limitation — annotations don't participate in rewriting
    error("Cannot reconstruct Ann via maketerm without annotation context")
end
