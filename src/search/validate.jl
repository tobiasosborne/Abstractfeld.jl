# Tactic submission and validation — closes the loop:
# e-graph discovers equivalence → LLM proposes proof → Lean verifies.

"""
    validate_proof(claim::Claim, tactics::String; timeout=60.0) → VerificationResult

Submit LLM-generated tactics for a claim to Lean for verification.
"""
function validate_proof(claim::Claim, tactics::String; timeout::Float64=60.0)
    verify(claim; tactic=tactics, timeout)
end

"""
    attempt_prove(claim::Claim; model="claude-sonnet-4-20250514", max_llm_attempts=3,
                  max_repair_attempts=2, timeout=60.0, hint_lemmas=String[]) → VerificationResult

Full prove loop: LLM generates tactics → Lean verifies → retry with error feedback on rejection.
"""
function attempt_prove(claim::Claim;
        model::String="claude-sonnet-4-20250514",
        max_llm_attempts::Int=3,
        max_repair_attempts::Int=2,
        timeout::Float64=60.0,
        hint_lemmas::Vector{String}=String[])

    # Phase 1: Generate initial tactic
    tactics = generate_tactics(claim; model, max_attempts=max_llm_attempts, hint_lemmas)
    isnothing(tactics) && return Rejected("LLM failed to generate tactics after $max_llm_attempts attempts")

    # Phase 2: Verify
    result = validate_proof(claim, tactics; timeout)
    result isa Verified && return result

    # Phase 3: Compiler-guided repair — feed error back to LLM
    for repair in 1:max_repair_attempts
        error_msg = result isa Rejected ? result.error_msg : "Timeout after $(timeout)s"
        repair_prompt = _repair_prompt(claim, tactics, error_msg; hint_lemmas)

        try
            response = call_anthropic(repair_prompt; model)
            new_tactics = parse_tactic_block(response)
            isnothing(new_tactics) && continue

            result = validate_proof(claim, new_tactics; timeout)
            result isa Verified && return result
            tactics = new_tactics  # use latest attempt for next repair
        catch e
            @warn "Repair attempt $repair failed" exception=e
        end
    end

    result  # return last failure
end

function _repair_prompt(claim::Claim, failed_tactics::String, error_msg::String;
        hint_lemmas::Vector{String}=String[])
    parts = String[]
    push!(parts, """You are a Lean 4 proof assistant. Your previous proof attempt FAILED.
Fix the proof based on the compiler error below. Output ONLY the corrected `by` tactic block.""")

    push!(parts, "\n## Claim")
    push!(parts, "**LaTeX:** \$$(render_latex(claim.lhs)) = $(render_latex(claim.rhs))\$")
    push!(parts, "**S-expr LHS:** `$(to_sexpr(claim.lhs))`")
    push!(parts, "**S-expr RHS:** `$(to_sexpr(claim.rhs))`")

    push!(parts, "\n## Failed proof\n```lean\n$(failed_tactics)\n```")
    push!(parts, "\n## Lean compiler error\n```\n$(first(error_msg, 2000))\n```")

    if !isempty(hint_lemmas)
        push!(parts, "\n## Available lemmas")
        for l in hint_lemmas
            push!(parts, "- `$l`")
        end
    end

    push!(parts, "\n## Instructions\nFix the error. Output ONLY the corrected `by` tactic block.")
    join(parts, "\n")
end
