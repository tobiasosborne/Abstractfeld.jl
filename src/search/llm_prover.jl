# LLM tactic generator — calls Claude API to generate Lean 4 tactic proofs.
# The LLM is a replaceable component: claim in → tactic block out.

using HTTP
using JSON3

"""
    parse_tactic_block(response::String) → Union{String, Nothing}

Extract a Lean 4 tactic block from an LLM response.
Handles common formats: fenced code blocks, raw tactics, etc.
"""
function parse_tactic_block(response::String)
    s = strip(response)
    isempty(s) && return nothing

    # Try to extract from ```lean ... ``` fenced block
    m = match(r"```(?:lean)?\s*\n?(.*?)```"s, s)
    if !isnothing(m)
        block = strip(m.captures[1])
        # Remove leading `by` if present (we'll add it ourselves)
        block = _normalize_tactic(block)
        return isempty(block) ? nothing : block
    end

    # Try raw tactic block (starts with `by`)
    m2 = match(r"^by\b"m, s)
    if !isnothing(m2)
        return _normalize_tactic(s)
    end

    # Try bare tactics (simp, ring, omega, etc.)
    if occursin(r"^\s*(simp|ring|omega|linarith|exact|rfl|trivial|decide|norm_num|apply|rw|intro)"m, s)
        return "by\n  " * s
    end

    nothing
end

function _normalize_tactic(s::AbstractString)
    s = strip(s)
    # Ensure it starts with `by`
    startswith(s, "by") && return s
    "by\n  " * s
end

"""
    call_anthropic(prompt::String; model="claude-sonnet-4-20250514", max_tokens=1024, temperature=0.0) → String

Call the Anthropic Messages API. Returns the text response.
Requires `ENV["ANTHROPIC_API_KEY"]` to be set.
"""
function call_anthropic(prompt::String;
        model::String="claude-sonnet-4-20250514",
        max_tokens::Int=1024,
        temperature::Float64=0.0)
    api_key = get(ENV, "ANTHROPIC_API_KEY", "")
    isempty(api_key) && error("ANTHROPIC_API_KEY not set")

    body = JSON3.write(Dict(
        "model" => model,
        "max_tokens" => max_tokens,
        "temperature" => temperature,
        "messages" => [Dict("role" => "user", "content" => prompt)]
    ))

    resp = HTTP.post(
        "https://api.anthropic.com/v1/messages",
        ["Content-Type" => "application/json",
         "x-api-key" => api_key,
         "anthropic-version" => "2023-06-01"],
        body;
        status_exception=false,
        readtimeout=120)

    if resp.status != 200
        error("Anthropic API error $(resp.status): $(String(resp.body))")
    end

    data = JSON3.read(String(resp.body))
    # Extract text from content blocks
    for block in data.content
        if block.type == "text"
            return block.text
        end
    end
    error("No text content in API response")
end

"""
    generate_tactics(claim::Claim; model="claude-sonnet-4-20250514", max_attempts=3,
                     hint_lemmas=String[], similar_proofs=String[]) → Union{String, Nothing}

Generate Lean 4 tactics for a claim using an LLM.
Returns a tactic block string, or `nothing` on failure.
"""
function generate_tactics(claim::Claim;
        model::String="claude-sonnet-4-20250514",
        max_attempts::Int=3,
        hint_lemmas::Vector{String}=String[],
        similar_proofs::Vector{String}=String[])

    prompt = format_prompt(claim;
        hint_lemmas, similar_proofs,
        lean_imports=["Abstractfeld.Tensor.Identities"])

    for attempt in 1:max_attempts
        try
            response = call_anthropic(prompt; model)
            tactic = parse_tactic_block(response)
            !isnothing(tactic) && return tactic
            @warn "Attempt $attempt: could not parse tactic from response"
        catch e
            @warn "Attempt $attempt failed" exception=e
            attempt < max_attempts && sleep(1.0)
        end
    end

    nothing
end
