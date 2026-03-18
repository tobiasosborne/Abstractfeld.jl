# Claim-to-prompt formatter for LLM tactic generation.
# Turns Claim objects into structured prompts that guide an LLM
# to produce valid Lean 4 tactic proofs.

"""
    render_lean_theorem_stmt(claim::Claim; name="claim") → String

Generate a Lean 4 theorem statement from a claim.
The statement asserts lhs = rhs for appropriate Mathlib types.
"""
function render_lean_theorem_stmt(claim::Claim; name::String="claim")
    lhs_s = to_sexpr(claim.lhs)
    rhs_s = to_sexpr(claim.rhs)
    """theorem $name :
    -- lhs: $lhs_s
    -- rhs: $rhs_s
    ∀ (f : AlternatingMap ℚ M ℚ (Fin k)) (v : Fin k → M),
      eval_lhs f v = eval_rhs f v := by
    sorry -- REPLACE WITH TACTIC PROOF"""
end

"""
    format_prompt(claim::Claim; similar_proofs=String[], hint_lemmas=String[], lean_imports=String[]) → String

Format a claim into a structured prompt for LLM tactic generation.
"""
function format_prompt(claim::Claim;
        similar_proofs::Vector{String}=String[],
        hint_lemmas::Vector{String}=String[],
        lean_imports::Vector{String}=String[])

    parts = String[]

    # System instruction
    push!(parts, """You are a Lean 4 proof assistant specializing in algebraic identities.
Generate a tactic proof for the following theorem. Output ONLY the tactic block (starting with `by`), no explanation.""")

    # Claim in human-readable form
    push!(parts, "\n## Claim\n")
    push!(parts, "**LaTeX:** \$$(render_latex(claim.lhs)) = $(render_latex(claim.rhs))\$")
    push!(parts, "**S-expr LHS:** `$(to_sexpr(claim.lhs))`")
    push!(parts, "**S-expr RHS:** `$(to_sexpr(claim.rhs))`")

    # E-graph hints
    if !isempty(claim.rules_used)
        push!(parts, "\n## E-graph hints\nThe equality saturation engine used these rule categories: $(join(string.(claim.rules_used), ", "))")
    end

    # Lean theorem statement
    push!(parts, "\n## Lean 4 theorem to prove\n```lean")
    if !isempty(lean_imports)
        for imp in lean_imports
            push!(parts, "import $imp")
        end
        push!(parts, "")
    end
    push!(parts, render_lean_theorem_stmt(claim))
    push!(parts, "```")

    # Hint lemmas
    if !isempty(hint_lemmas)
        push!(parts, "\n## Potentially useful Mathlib lemmas")
        for l in hint_lemmas
            push!(parts, "- `$l`")
        end
    end

    # Similar proofs from KB
    if !isempty(similar_proofs)
        push!(parts, "\n## Similar verified proofs (from knowledge base)")
        for p in similar_proofs
            push!(parts, "```lean\n$p\n```")
        end
    end

    # Final instruction
    push!(parts, "\n## Instructions\nOutput ONLY the `by` tactic block. Use `simp`, `ring`, `omega`, `linarith`, `exact`, or Mathlib-specific tactics as needed. Do not add imports or theorem declarations.")

    join(parts, "\n")
end
