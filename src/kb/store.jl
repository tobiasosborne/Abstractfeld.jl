# Store verified results with provenance tracking.
# Wraps the schema layer with deduplication and provenance chain management.

using SHA: sha256

"""
    VerifiedResult

A verified mathematical identity with full provenance.
"""
struct VerifiedResult
    claim::Claim
    level::Int
    proof_artifact::String
    generator::Symbol
end

"""
    store!(kb::KnowledgeBase, vr::VerifiedResult) → Int

Store a verified result in the knowledge base.
- Computes structural hash for deduplication
- If hash exists with lower level, upgrades the level
- Returns the result ID
"""
function store!(kb::KnowledgeBase, vr::VerifiedResult)
    h = sha256(to_sexpr(vr.claim.lhs) * "=" * to_sexpr(vr.claim.rhs))
    h_bytes = Vector{UInt8}(h)

    # Check for existing entry with same hash
    existing = DuckDB.execute(kb.con,
        "SELECT id, verification_level FROM results WHERE expr_hash = ?",
        [h_bytes])
    df = DuckDB.toDataFrame(existing)

    if length(df.id) > 0
        existing_id = Int(df.id[1])
        existing_level = Int(df.verification_level[1])
        if vr.level > existing_level
            update_level!(kb, existing_id, vr.level;
                proof=isempty(vr.proof_artifact) ? nothing : vr.proof_artifact)
        end
        return existing_id
    end

    # Insert new
    proof = isempty(vr.proof_artifact) ? nothing : vr.proof_artifact
    id = insert_result!(kb, vr.claim;
        level=vr.level, proof, generator=vr.generator)

    # Store numerical fingerprint for L2 fuzzy matching
    fp = numerical_fingerprint(vr.claim.lhs)
    insert_fingerprint!(kb, id, fp)

    id
end

"""
    store_from_verification!(kb::KnowledgeBase, claim::Claim, result::Verified; generator=:llm) → Int

Convenience: store a successfully verified claim directly from a VerificationResult.
"""
function store_from_verification!(kb::KnowledgeBase, claim::Claim, result::Verified;
        generator::Symbol=:llm)
    vr = VerifiedResult(claim, 4, result.proof_artifact, generator)
    store!(kb, vr)
end
