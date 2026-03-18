"""
    JSON serialization for the IR.

Used for Julia↔Lean bridge communication. JSON is the wire format;
S-expressions are the canonical/hashing format.
"""

using JSON3

"""
    to_json(e::Expr) → String

Serialize an expression to JSON for Lean bridge communication.
"""
function to_json(e::Lit)
    JSON3.write(Dict("tag" => "lit", "val" => string(e.val)))
end

function to_json(e::Sym)
    JSON3.write(Dict("tag" => "sym", "name" => string(e.name)))
end

function to_json(e::Idx)
    JSON3.write(Dict("tag" => "idx", "name" => string(e.name), "pos" => e.pos == Up ? "up" : "down"))
end

function to_json(e::App)
    JSON3.write(Dict("tag" => "app", "op" => string(e.op), "args" => [JSON3.read(to_json(a)) for a in e.args]))
end

function to_json(e::Bind)
    JSON3.write(Dict(
        "tag" => "bind",
        "binder" => string(e.binder),
        "var" => JSON3.read(to_json(e.var)),
        "body" => JSON3.read(to_json(e.body)),
        "metadata" => [JSON3.read(to_json(m)) for m in e.metadata]
    ))
end

function to_json(e::Ann)
    JSON3.write(Dict(
        "tag" => "ann",
        "expr" => JSON3.read(to_json(e.expr)),
        "ann" => _ann_json(e.ann)
    ))
end

_ann_json(a::SymmetryAnn) = Dict("tag" => "symmetry", "kind" => string(a.kind), "slots" => a.slots)
_ann_json(a::TypeAnn) = Dict("tag" => "type", "name" => string(a.tag))

"""
    from_json(s::AbstractString) → Expr

Deserialize JSON back to an Expr.
"""
function from_json(s::AbstractString)
    d = JSON3.read(s)
    _from_json_dict(d)
end

function _from_json_dict(d)
    tag = d["tag"]
    if tag == "lit"
        val_str = d["val"]
        if occursin("//", val_str)
            parts = split(val_str, "//")
            return Lit(Rational{BigInt}(parse(BigInt, parts[1]), parse(BigInt, parts[2])))
        else
            return Lit(Rational{BigInt}(parse(BigInt, val_str)))
        end
    elseif tag == "sym"
        return Sym(Symbol(d["name"]))
    elseif tag == "idx"
        pos = d["pos"] == "up" ? Up : Down
        return Idx(Symbol(d["name"]), pos)
    elseif tag == "app"
        args = [_from_json_dict(a) for a in d["args"]]
        return App(Symbol(d["op"]), args)
    elseif tag == "bind"
        var = _from_json_dict(d["var"])
        body = _from_json_dict(d["body"])
        metadata = [_from_json_dict(m) for m in d["metadata"]]
        return Bind(Symbol(d["binder"]), var, body, metadata)
    elseif tag == "ann"
        expr = _from_json_dict(d["expr"])
        ann_d = d["ann"]
        annotation = if ann_d["tag"] == "symmetry"
            SymmetryAnn(Symbol(ann_d["kind"]), Int[s for s in ann_d["slots"]])
        else
            TypeAnn(Symbol(ann_d["name"]))
        end
        return Ann(expr, annotation)
    else
        error("Unknown JSON tag: $tag")
    end
end
