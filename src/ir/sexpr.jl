"""
    S-expression serialization for the IR.

Canonical format: deterministic output, parseable back to identical Expr.
This is the interchange format between Julia and Lean, and the input to structural hashing.
"""

# ============================================================
# Serialization: Expr → String
# ============================================================

"""
    to_sexpr(e::Expr) → String

Serialize an expression to its canonical S-expression form.
Deterministic: same Expr always produces the same String.
"""
function to_sexpr(e::Lit)
    v = e.val
    if isone(denominator(v))
        return "(lit $(numerator(v)))"
    else
        return "(lit $(numerator(v))/$(denominator(v)))"
    end
end

to_sexpr(e::Sym) = "(sym $(e.name))"

to_sexpr(e::Idx) = "(idx $(e.name) $(e.pos == Up ? "up" : "down"))"

function to_sexpr(e::App)
    parts = [string(e.op); [to_sexpr(a) for a in e.args]]
    return "(app " * join(parts, " ") * ")"
end

function to_sexpr(e::Bind)
    parts = [string(e.binder), to_sexpr(e.var), to_sexpr(e.body)]
    append!(parts, [to_sexpr(m) for m in e.metadata])
    return "(bind " * join(parts, " ") * ")"
end

function to_sexpr(e::Ann)
    return "(ann " * to_sexpr(e.expr) * " " * _ann_sexpr(e.ann) * ")"
end

_ann_sexpr(a::SymmetryAnn) = "(symmetry $(a.kind) " * join(string.(a.slots), " ") * ")"
_ann_sexpr(a::TypeAnn) = "(type $(a.tag))"

# ============================================================
# Parsing: String → Expr
# ============================================================

struct ParseError <: Exception
    msg::String
    pos::Int
end
Base.showerror(io::IO, e::ParseError) = print(io, "ParseError at position $(e.pos): $(e.msg)")

"""
    parse_sexpr(s::String) → Expr

Parse an S-expression string back into an Expr.
Inverse of `to_sexpr`: `parse_sexpr(to_sexpr(e)) == e` for all valid expressions.
"""
function parse_sexpr(s::AbstractString)
    s = String(strip(s))
    expr, pos = _parse(s, 1)
    pos = _skipws(s, pos)
    if pos <= length(s)
        throw(ParseError("unexpected trailing content", pos))
    end
    return expr
end

function _skipws(s::String, pos::Int)
    while pos <= length(s) && isspace(s[pos])
        pos += 1
    end
    return pos
end

function _expect(s::String, pos::Int, ch::Char)
    if pos > length(s) || s[pos] != ch
        throw(ParseError("expected '$(ch)'", pos))
    end
    return pos + 1
end

function _read_token(s::String, pos::Int)
    start = pos
    while pos <= length(s) && !isspace(s[pos]) && s[pos] != '(' && s[pos] != ')'
        pos += 1
    end
    if pos == start
        throw(ParseError("expected token", pos))
    end
    return s[start:pos-1], pos
end

function _parse(s::String, pos::Int)
    pos = _skipws(s, pos)
    if pos > length(s)
        throw(ParseError("unexpected end of input", pos))
    end
    pos = _expect(s, pos, '(')
    pos = _skipws(s, pos)

    tag, pos = _read_token(s, pos)
    pos = _skipws(s, pos)

    result = if tag == "lit"
        _parse_lit(s, pos)
    elseif tag == "sym"
        _parse_sym(s, pos)
    elseif tag == "idx"
        _parse_idx(s, pos)
    elseif tag == "app"
        _parse_app(s, pos)
    elseif tag == "bind"
        _parse_bind(s, pos)
    elseif tag == "ann"
        _parse_ann(s, pos)
    else
        throw(ParseError("unknown tag '$tag'", pos))
    end

    expr, pos = result
    pos = _skipws(s, pos)
    pos = _expect(s, pos, ')')
    return expr, pos
end

function _parse_lit(s::String, pos::Int)
    token, pos = _read_token(s, pos)
    if occursin('/', token)
        parts = split(token, '/')
        length(parts) == 2 || throw(ParseError("malformed rational '$token'", pos))
        val = Rational{BigInt}(parse(BigInt, parts[1]), parse(BigInt, parts[2]))
    else
        val = Rational{BigInt}(parse(BigInt, token))
    end
    return Lit(val), pos
end

function _parse_sym(s::String, pos::Int)
    token, pos = _read_token(s, pos)
    return Sym(Symbol(token)), pos
end

function _parse_idx(s::String, pos::Int)
    name, pos = _read_token(s, pos)
    pos = _skipws(s, pos)
    posstr, pos = _read_token(s, pos)
    p = posstr == "up" ? Up : posstr == "down" ? Down : throw(ParseError("expected 'up' or 'down', got '$posstr'", pos))
    return Idx(Symbol(name), p), pos
end

function _parse_app(s::String, pos::Int)
    op, pos = _read_token(s, pos)
    args = Expr[]
    pos = _skipws(s, pos)
    while pos <= length(s) && s[pos] != ')'
        arg, pos = _parse(s, pos)
        push!(args, arg)
        pos = _skipws(s, pos)
    end
    return App(Symbol(op), args), pos
end

function _parse_bind(s::String, pos::Int)
    binder, pos = _read_token(s, pos)
    pos = _skipws(s, pos)
    var, pos = _parse(s, pos)
    pos = _skipws(s, pos)
    body, pos = _parse(s, pos)
    metadata = Expr[]
    pos = _skipws(s, pos)
    while pos <= length(s) && s[pos] != ')'
        m, pos = _parse(s, pos)
        push!(metadata, m)
        pos = _skipws(s, pos)
    end
    return Bind(Symbol(binder), var, body, metadata), pos
end

function _parse_ann(s::String, pos::Int)
    expr, pos = _parse(s, pos)
    pos = _skipws(s, pos)
    ann, pos = _parse_annotation(s, pos)
    return Ann(expr, ann), pos
end

function _parse_annotation(s::String, pos::Int)
    pos = _skipws(s, pos)
    pos = _expect(s, pos, '(')
    pos = _skipws(s, pos)
    tag, pos = _read_token(s, pos)
    pos = _skipws(s, pos)

    ann = if tag == "symmetry"
        kind, pos = _read_token(s, pos)
        slots = Int[]
        pos = _skipws(s, pos)
        while pos <= length(s) && s[pos] != ')'
            slot, pos = _read_token(s, pos)
            push!(slots, parse(Int, slot))
            pos = _skipws(s, pos)
        end
        SymmetryAnn(Symbol(kind), slots), pos
    elseif tag == "type"
        t, pos = _read_token(s, pos)
        TypeAnn(Symbol(t)), pos
    else
        throw(ParseError("unknown annotation tag '$tag'", pos))
    end

    result_ann, pos = ann
    pos = _skipws(s, pos)
    pos = _expect(s, pos, ')')
    return result_ann, pos
end
