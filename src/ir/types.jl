"""
    Abstractfeld IR — the unified intermediate representation.

Six node types: Lit, Sym, Idx, App, Bind, Ann.
All structs are immutable. Names are Symbols (interned). Coefficients are exact rationals.
"""

# --- Index position ---

@enum IndexPos Up Down

# --- Annotation types ---

abstract type Annotation end

"""Symmetry annotation (e.g., antisymmetric in slots 1,2)."""
struct SymmetryAnn <: Annotation
    kind::Symbol          # :antisym, :sym, :cyclic, ...
    slots::Vector{Int}
end

"""Type annotation (e.g., :real, :complex, :tensor_rank_4)."""
struct TypeAnn <: Annotation
    tag::Symbol
end

Base.:(==)(a::SymmetryAnn, b::SymmetryAnn) = a.kind == b.kind && a.slots == b.slots
Base.:(==)(a::TypeAnn, b::TypeAnn) = a.tag == b.tag
Base.hash(a::SymmetryAnn, h::UInt) = hash(a.slots, hash(a.kind, hash(:SymmetryAnn, h)))
Base.hash(a::TypeAnn, h::UInt) = hash(a.tag, hash(:TypeAnn, h))

# --- IR node types ---

abstract type Expr end

"""Exact rational literal."""
struct Lit <: Expr
    val::Rational{BigInt}
end

"""Named symbol (variable, constant, tensor name)."""
struct Sym <: Expr
    name::Symbol
end

"""Tensor index with position (up/down)."""
struct Idx <: Expr
    name::Symbol
    pos::IndexPos
end

"""Function/operator application."""
struct App <: Expr
    op::Symbol
    args::Vector{Expr}
end

"""Binding form (integral, sum, derivative)."""
struct Bind <: Expr
    binder::Symbol
    var::Expr
    body::Expr
    metadata::Vector{Expr}
end

"""Annotated expression."""
struct Ann <: Expr
    expr::Expr
    ann::Annotation
end

# --- Equality and hashing ---

Base.:(==)(a::Lit, b::Lit) = a.val == b.val
Base.:(==)(a::Sym, b::Sym) = a.name == b.name
Base.:(==)(a::Idx, b::Idx) = a.name == b.name && a.pos == b.pos
Base.:(==)(a::App, b::App) = a.op == b.op && a.args == b.args
Base.:(==)(a::Bind, b::Bind) = a.binder == b.binder && a.var == b.var && a.body == b.body && a.metadata == b.metadata
Base.:(==)(a::Ann, b::Ann) = a.expr == b.expr && a.ann == b.ann
Base.:(==)(::Expr, ::Expr) = false  # different types are never equal

Base.hash(e::Lit, h::UInt) = hash(e.val, hash(:Lit, h))
Base.hash(e::Sym, h::UInt) = hash(e.name, hash(:Sym, h))
Base.hash(e::Idx, h::UInt) = hash(e.pos, hash(e.name, hash(:Idx, h)))
Base.hash(e::App, h::UInt) = hash(e.args, hash(e.op, hash(:App, h)))
Base.hash(e::Bind, h::UInt) = hash(e.metadata, hash(e.body, hash(e.var, hash(e.binder, hash(:Bind, h)))))
Base.hash(e::Ann, h::UInt) = hash(e.ann, hash(e.expr, hash(:Ann, h)))

# --- Convenience constructors ---

"""    lit(v) — rational literal. Accepts Int, Rational, or BigInt."""
lit(v::Integer) = Lit(Rational{BigInt}(v))
lit(v::Rational) = Lit(Rational{BigInt}(v))

"""    sym(name) — named symbol."""
sym(name::Symbol) = Sym(name)
sym(name::AbstractString) = Sym(Symbol(name))

"""    idx(name, pos) — tensor index."""
idx(name::Symbol, pos::IndexPos) = Idx(name, pos)
idx(name::AbstractString, pos::IndexPos) = Idx(Symbol(name), pos)

"""    app(op, args...) — operator application."""
app(op::Symbol, args::Expr...) = App(op, collect(Expr, args))
app(op::AbstractString, args::Expr...) = app(Symbol(op), args...)

"""    bnd(binder, var, body, metadata...) — binding form constructor."""
bnd(binder::Symbol, var::Expr, body::Expr, metadata::Expr...) = Bind(binder, var, body, collect(Expr, metadata))

"""    ann(expr, annotation) — annotated expression."""
ann(expr::Expr, a::Annotation) = Ann(expr, a)

"""    tensor(name, indices...) — convenience for tensor expressions."""
function tensor(name::Symbol, indices::Idx...)
    App(:tensor, Expr[Sym(name); collect(Expr, indices)])
end
tensor(name::AbstractString, indices::Idx...) = tensor(Symbol(name), indices...)
