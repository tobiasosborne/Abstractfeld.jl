# Knowledge base schema — DuckDB storage for verified mathematical results.
# Supports the verification lattice: L0 (unverified) → L4 (formally verified).

using DuckDB
using SHA: sha256

"""
    KnowledgeBase

A DuckDB-backed store of verified mathematical results.
"""
struct KnowledgeBase
    db::DuckDB.DB
    con::DuckDB.Connection
end

"""
    create_kb(path::String=":memory:") → KnowledgeBase

Create or open a knowledge base at the given path.
"""
function create_kb(path::String=":memory:")
    db = DuckDB.DB(path)
    con = DuckDB.connect(db)
    _migrate!(con)
    KnowledgeBase(db, con)
end

"""
    close_kb!(kb::KnowledgeBase)

Close the knowledge base connection.
"""
function close_kb!(kb::KnowledgeBase)
    DuckDB.disconnect(kb.con)
    DuckDB.close(kb.db)
end

function _migrate!(con)
    DuckDB.execute(con, "CREATE SEQUENCE IF NOT EXISTS results_seq START 1")
    DuckDB.execute(con, raw"""CREATE TABLE IF NOT EXISTS results (
        id              INTEGER PRIMARY KEY DEFAULT nextval('results_seq'),
        expr_hash       BLOB NOT NULL,
        lhs_sexpr       TEXT NOT NULL,
        rhs_sexpr       TEXT NOT NULL,
        verification_level INTEGER NOT NULL DEFAULT 0,
        lean_proof       TEXT DEFAULT NULL,
        created_at       TIMESTAMP DEFAULT current_timestamp,
        provenance       TEXT DEFAULT '[]'
    )""")
    DuckDB.execute(con, raw"""CREATE TABLE IF NOT EXISTS fingerprints (
        result_id       INTEGER NOT NULL,
        fingerprint     BLOB NOT NULL
    )""")
    DuckDB.execute(con, "CREATE INDEX IF NOT EXISTS idx_results_hash ON results(expr_hash)")
    DuckDB.execute(con, "CREATE INDEX IF NOT EXISTS idx_results_level ON results(verification_level)")
    DuckDB.execute(con, "CREATE INDEX IF NOT EXISTS idx_fingerprints_result ON fingerprints(result_id)")
end

"""
    insert_result!(kb, claim::Claim; level=0, proof=nothing, generator=:egraph) → Int

Insert a verified result into the knowledge base. Returns the row ID.
"""
function insert_result!(kb::KnowledgeBase, claim::Claim;
        level::Int=0, proof::Union{String,Nothing}=nothing, generator::Symbol=:egraph)
    h = sha256(to_sexpr(claim.lhs) * "=" * to_sexpr(claim.rhs))
    provenance = """[{"generator":"$generator","level":$level}]"""
    DuckDB.execute(kb.con,
        "INSERT INTO results (expr_hash, lhs_sexpr, rhs_sexpr, verification_level, lean_proof, provenance) VALUES (?, ?, ?, ?, ?, ?)",
        [Vector{UInt8}(h), to_sexpr(claim.lhs), to_sexpr(claim.rhs), level, something(proof, missing), provenance])
    r = DuckDB.execute(kb.con, "SELECT MAX(id) as maxid FROM results")
    df = DuckDB.toDataFrame(r)
    Int(df.maxid[1])
end

"""
    insert_fingerprint!(kb, result_id::Int, fp::Vector{UInt8})

Store a numerical fingerprint for a result.
"""
function insert_fingerprint!(kb::KnowledgeBase, result_id::Int, fp::Vector{UInt8})
    DuckDB.execute(kb.con,
        "INSERT INTO fingerprints (result_id, fingerprint) VALUES (?, ?)",
        [result_id, fp])
end

"""
    lookup_by_hash(kb, hash::String) → Vector

Look up results by expression hash.
"""
function lookup_by_hash(kb::KnowledgeBase, hash::String)
    r = DuckDB.execute(kb.con,
        "SELECT id, lhs_sexpr, rhs_sexpr, verification_level, lean_proof, provenance FROM results WHERE expr_hash = ?",
        [Vector{UInt8}(hash)])
    DuckDB.toDataFrame(r)
end

"""
    lookup_by_level(kb, min_level::Int) → DataFrame

Look up all results at or above the given verification level.
"""
function lookup_by_level(kb::KnowledgeBase, min_level::Int)
    r = DuckDB.execute(kb.con,
        "SELECT id, lhs_sexpr, rhs_sexpr, verification_level FROM results WHERE verification_level >= ? ORDER BY verification_level DESC",
        [min_level])
    DuckDB.toDataFrame(r)
end

"""
    update_level!(kb, id::Int, new_level::Int; proof=nothing)

Upgrade the verification level of a result (e.g., after Lean proof).
"""
function update_level!(kb::KnowledgeBase, id::Int, new_level::Int; proof::Union{String,Nothing}=nothing)
    if isnothing(proof)
        DuckDB.execute(kb.con,
            "UPDATE results SET verification_level = ? WHERE id = ? AND verification_level < ?",
            [new_level, id, new_level])
    else
        DuckDB.execute(kb.con,
            "UPDATE results SET verification_level = ?, lean_proof = ? WHERE id = ? AND verification_level < ?",
            [new_level, proof, id, new_level])
    end
end

"""
    kb_stats(kb) → NamedTuple

Get summary statistics for the knowledge base.
"""
function kb_stats(kb::KnowledgeBase)
    r = DuckDB.execute(kb.con, """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN verification_level = 0 THEN 1 ELSE 0 END) as l0,
            SUM(CASE WHEN verification_level = 1 THEN 1 ELSE 0 END) as l1,
            SUM(CASE WHEN verification_level = 2 THEN 1 ELSE 0 END) as l2,
            SUM(CASE WHEN verification_level = 3 THEN 1 ELSE 0 END) as l3,
            SUM(CASE WHEN verification_level = 4 THEN 1 ELSE 0 END) as l4
        FROM results
    """)
    df = DuckDB.toDataFrame(r)
    (total=Int(df.total[1]), l0=Int(df.l0[1]), l1=Int(df.l1[1]),
     l2=Int(df.l2[1]), l3=Int(df.l3[1]), l4=Int(df.l4[1]))
end
