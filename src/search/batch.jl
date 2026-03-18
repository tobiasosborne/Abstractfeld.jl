# Batch verification runner — the flywheel.
# Each verified result improves retrieval for subsequent claims.

"""
    BatchReport

Summary of a batch verification run.
"""
struct BatchReport
    total::Int
    verified::Int
    rejected::Int
    timeout::Int
    skipped_cached::Int
    skipped_numerical::Int
    elapsed::Float64
    results::Vector{Pair{Claim, VerificationResult}}
end

function Base.show(io::IO, r::BatchReport)
    rate = r.total > 0 ? round(r.verified / r.total * 100; digits=1) : 0.0
    print(io, "BatchReport($(r.total) claims: $(r.verified) verified, $(r.rejected) rejected, ",
          "$(r.timeout) timeout, $(r.skipped_cached) cached, $(r.skipped_numerical) filtered, ",
          "$(rate)% success, $(round(r.elapsed; digits=1))s)")
end

"""
    batch_verify(claims::Vector{Claim}, kb::KnowledgeBase;
                 model="claude-sonnet-4-20250514", timeout=60.0, skip_cached=true,
                 skip_numerical=true) → BatchReport

Submit multiple claims for verification through the full pipeline:
1. Check KB cache (skip if already verified)
2. Numerical pre-filter (skip if L2 fails)
3. Retrieve similar proofs from KB for LLM context
4. LLM generates tactics
5. Lean verifies
6. Store result in KB
"""
function batch_verify(claims::Vector{Claim}, kb::KnowledgeBase;
        model::String="claude-sonnet-4-20250514",
        timeout::Float64=60.0,
        skip_cached::Bool=true,
        skip_numerical::Bool=true)

    start_time = time()
    results = Pair{Claim, VerificationResult}[]
    n_verified = 0
    n_rejected = 0
    n_timeout = 0
    n_cached = 0
    n_numerical = 0

    for (i, claim) in enumerate(claims)
        @info "[$i/$(length(claims))] Processing: $(to_sexpr(claim.lhs)) = $(to_sexpr(claim.rhs))"

        # Step 1: Check KB cache
        if skip_cached && has_claim(kb, claim.lhs, claim.rhs; min_level=4)
            @info "  → Skipped (already L4 verified)"
            n_cached += 1
            push!(results, claim => Verified("cached"))
            n_verified += 1
            continue
        end

        # Step 2: Numerical pre-filter
        if skip_numerical && !verify_claim_numerically(claim; n_points=50)
            @info "  → Rejected by numerical pre-filter"
            n_numerical += 1
            push!(results, claim => Rejected("Failed numerical pre-filter"))
            n_rejected += 1
            continue
        end

        # Step 3: Retrieve similar proofs
        proofs = find_similar_proofs(claim, kb; k=3)
        hint_lemmas = _suggest_lemmas(claim)

        # Step 4-5: LLM → Lean
        result = attempt_prove(claim;
            model, max_llm_attempts=2, max_repair_attempts=1,
            timeout, hint_lemmas)

        push!(results, claim => result)

        if result isa Verified
            n_verified += 1
            # Step 6: Store in KB
            store_from_verification!(kb, claim, result; generator=:llm)
            @info "  → Verified! Stored in KB at L4."
        elseif result isa VerificationTimeout
            n_timeout += 1
            @info "  → Timeout"
        else
            n_rejected += 1
            @info "  → Rejected"
        end
    end

    elapsed = time() - start_time
    BatchReport(length(claims), n_verified, n_rejected, n_timeout, n_cached, n_numerical, elapsed, results)
end

# Suggest relevant Mathlib lemmas based on claim content
function _suggest_lemmas(claim::Claim)
    lemmas = String[]
    lhs_str = to_sexpr(claim.lhs)
    rhs_str = to_sexpr(claim.rhs)
    combined = lhs_str * rhs_str

    occursin("neg", combined) && push!(lemmas, "add_neg_cancel")
    occursin("+", combined) && push!(lemmas, "add_comm", "add_assoc")
    occursin("*", combined) && push!(lemmas, "mul_comm", "mul_assoc")
    occursin("tensor", combined) && push!(lemmas, "AlternatingMap.map_swap", "AlternatingMap.map_perm")

    lemmas
end
