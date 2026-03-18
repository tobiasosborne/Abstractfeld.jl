# Similar proof retrieval from KB — retrieval-augmented generation.
# More verified results → better retrieval → higher success rate → more verified results.

using SHA: sha256

"""
    find_similar(claim::Claim, kb::KnowledgeBase; k=5) → Vector{NamedTuple}

Find the k most similar verified results in the KB for a given claim.
Returns results ordered by relevance score (highest first).
"""
function find_similar(claim::Claim, kb::KnowledgeBase; k::Int=5)
    results = all_results(kb; min_level=1)
    isempty(results) && return typeof(results)()

    claim_hash = sha256(to_sexpr(claim.lhs) * "=" * to_sexpr(claim.rhs))
    claim_fp = numerical_fingerprint(claim.lhs)

    scored = [(result=r, score=_relevance_score(claim, claim_hash, claim_fp, r, kb)) for r in results]
    sort!(scored; by=x -> x.score, rev=true)

    [s.result for s in scored[1:min(k, length(scored))]]
end

"""
    find_similar_proofs(claim::Claim, kb::KnowledgeBase; k=5) → Vector{String}

Find similar verified proofs for LLM context. Returns Lean proof strings.
"""
function find_similar_proofs(claim::Claim, kb::KnowledgeBase; k::Int=5)
    similar = find_similar(claim, kb; k)
    proofs = String[]
    for r in similar
        row = lookup_claim(kb, parse_sexpr(r.lhs), parse_sexpr(r.rhs))
        !isnothing(row) && !ismissing(row.proof) && !isempty(row.proof) && push!(proofs, row.proof)
    end
    proofs
end

function _relevance_score(claim::Claim, claim_hash, claim_fp, result, kb)
    score = 0.0

    # Hash prefix similarity (structural similarity)
    result_hash = sha256(result.lhs * "=" * result.rhs)
    prefix_match = _common_prefix_bytes(claim_hash, result_hash)
    score += 0.4 * min(prefix_match / 4.0, 1.0)

    # Fingerprint similarity (numerical similarity)
    r = DuckDB.execute(kb.con,
        "SELECT fingerprint FROM fingerprints WHERE result_id = ?",
        [result.id])
    df = DuckDB.toDataFrame(r)
    if !isempty(df.fingerprint)
        result_fp = Vector{UInt8}(df.fingerprint[1])
        fp_sim = _fingerprint_similarity(claim_fp, result_fp)
        score += 0.3 * fp_sim
    end

    # Expression structure overlap (shared symbols/operations)
    claim_syms = free_syms(claim.lhs) ∪ free_syms(claim.rhs)
    result_syms = _extract_syms(result.lhs) ∪ _extract_syms(result.rhs)
    if !isempty(claim_syms) || !isempty(result_syms)
        overlap = length(claim_syms ∩ result_syms) / max(length(claim_syms ∪ result_syms), 1)
        score += 0.3 * overlap
    end

    score
end

function _common_prefix_bytes(a::Vector{UInt8}, b::Vector{UInt8})
    n = min(length(a), length(b))
    for i in 1:n
        a[i] != b[i] && return i - 1
    end
    n
end

function _fingerprint_similarity(a::Vector{UInt8}, b::Vector{UInt8})
    length(a) != length(b) && return 0.0
    matches = sum(a .== b)
    matches / length(a)
end

function _extract_syms(sexpr::String)
    syms = Set{Symbol}()
    for m in eachmatch(r"\(sym\s+(\w+)\)", sexpr)
        push!(syms, Symbol(m.captures[1]))
    end
    syms
end
