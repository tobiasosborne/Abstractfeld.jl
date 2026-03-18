# Structural hash query and KB lookup utilities.

using SHA: sha256

"""
    lookup_claim(kb::KnowledgeBase, lhs, rhs) → Union{NamedTuple, Nothing}

Look up a specific claim by its LHS and RHS expressions.
Returns the result row or nothing if not found.
"""
function lookup_claim(kb::KnowledgeBase, lhs, rhs)
    h = sha256(to_sexpr(lhs) * "=" * to_sexpr(rhs))
    r = DuckDB.execute(kb.con,
        "SELECT id, lhs_sexpr, rhs_sexpr, verification_level, lean_proof, provenance FROM results WHERE expr_hash = ?",
        [Vector{UInt8}(h)])
    df = DuckDB.toDataFrame(r)
    isempty(df.id) && return nothing
    (id=Int(df.id[1]), lhs=df.lhs_sexpr[1], rhs=df.rhs_sexpr[1],
     level=Int(df.verification_level[1]),
     proof=df.lean_proof[1], provenance=df.provenance[1])
end

"""
    has_claim(kb::KnowledgeBase, lhs, rhs; min_level=0) → Bool

Check if a claim exists in the KB at the given minimum verification level.
"""
function has_claim(kb::KnowledgeBase, lhs, rhs; min_level::Int=0)
    result = lookup_claim(kb, lhs, rhs)
    !isnothing(result) && result.level >= min_level
end

"""
    similar_proofs(kb::KnowledgeBase; min_level=3, limit=5) → Vector{String}

Retrieve proof artifacts from the KB that could serve as examples for the LLM.
Returns Lean proof strings from results at or above the given level.
"""
function similar_proofs(kb::KnowledgeBase; min_level::Int=3, limit::Int=5)
    r = DuckDB.execute(kb.con,
        "SELECT lean_proof FROM results WHERE verification_level >= ? AND lean_proof IS NOT NULL LIMIT ?",
        [min_level, limit])
    df = DuckDB.toDataFrame(r)
    isempty(df.lean_proof) ? String[] : String[p for p in df.lean_proof if !ismissing(p)]
end

"""
    all_results(kb::KnowledgeBase; min_level=0) → Vector{NamedTuple}

Retrieve all results at or above the given verification level.
"""
function all_results(kb::KnowledgeBase; min_level::Int=0)
    r = DuckDB.execute(kb.con,
        "SELECT id, lhs_sexpr, rhs_sexpr, verification_level FROM results WHERE verification_level >= ? ORDER BY id",
        [min_level])
    df = DuckDB.toDataFrame(r)
    [(id=Int(df.id[i]), lhs=df.lhs_sexpr[i], rhs=df.rhs_sexpr[i], level=Int(df.verification_level[i]))
     for i in 1:length(df.id)]
end
