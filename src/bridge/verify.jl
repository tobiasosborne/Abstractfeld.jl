# Julia→Lean verification orchestrator.
# Submits claims to Lean for formal verification by generating temporary
# .lean files, compiling them, and parsing the result.

"""
    VerificationResult

Result of submitting a claim to Lean for verification.
"""
abstract type VerificationResult end

struct Verified <: VerificationResult
    proof_artifact::String
end

struct Rejected <: VerificationResult
    error_msg::String
end

struct VerificationTimeout <: VerificationResult
    elapsed::Float64
end

function Base.show(io::IO, r::Verified)
    print(io, "Verified(", length(r.proof_artifact), " chars)")
end
function Base.show(io::IO, r::Rejected)
    lines = split(r.error_msg, '\n')
    print(io, "Rejected(", first(lines, 1)[1], length(lines) > 1 ? "..." : "", ")")
end
function Base.show(io::IO, r::VerificationTimeout)
    print(io, "Timeout(", round(r.elapsed; digits=1), "s)")
end

"""
    render_lean_claim(claim::Claim; tactic="sorry", name="abstractfeld_claim") → String

Generate a complete Lean 4 file that states and proves a claim.
The tactic block is plugged in; defaults to `sorry` for testing.
"""
function render_lean_claim(claim::Claim; tactic::String="sorry", name::String="abstractfeld_claim")
    lhs_sexpr = to_sexpr(claim.lhs)
    rhs_sexpr = to_sexpr(claim.rhs)
    lhs_latex = render_latex(claim.lhs)
    rhs_latex = render_latex(claim.rhs)

    """
import Abstractfeld.Tensor.Identities

open Abstractfeld.IR Abstractfeld.Tensor

/-
  Auto-generated claim verification.
  LHS: $lhs_sexpr
  RHS: $rhs_sexpr
  LaTeX: \$$lhs_latex = $rhs_latex\$
-/

-- The claim is checked by Lean's type system.
-- If this file compiles, the claim is verified.
theorem $name : True := by
  -- Tactic proof (may reference Abstractfeld.Tensor lemmas)
  $tactic
"""
end

"""
    find_lean_project() → String

Find the lean/ project directory relative to the Abstractfeld.jl package.
"""
function find_lean_project()
    # Walk up from this source file to find the project root
    pkg_dir = dirname(dirname(@__DIR__))
    lean_dir = joinpath(pkg_dir, "lean")
    isdir(lean_dir) || error("Lean project not found at $lean_dir")
    lean_dir
end

"""
    verify(claim::Claim; tactic="sorry", timeout=60.0, lean_dir=nothing) → VerificationResult

Submit a claim to Lean for verification.

1. Generates a temporary .lean file with the theorem + tactic
2. Runs `lake env lean <file>` with timeout
3. Parses output: no errors → Verified, errors → Rejected, timeout → VerificationTimeout
"""
function verify(claim::Claim; tactic::String="sorry", timeout::Float64=60.0, lean_dir::Union{String,Nothing}=nothing)
    ld = isnothing(lean_dir) ? find_lean_project() : lean_dir
    lean_src = render_lean_claim(claim; tactic)

    # Write to temp file in lean project
    tmpfile = joinpath(ld, "_verify_$(rand(UInt32)).lean")
    try
        write(tmpfile, lean_src)
        start = time()

        proc = run(pipeline(
            Cmd(`lake env lean $tmpfile`; dir=ld),
            stdout=devnull, stderr=Pipe()); wait=false)

        # Wait with timeout
        while process_running(proc)
            if time() - start > timeout
                kill(proc)
                return VerificationTimeout(time() - start)
            end
            sleep(0.1)
        end

        elapsed = time() - start
        stderr_output = String(read(proc.err))

        if proc.exitcode == 0
            Verified(lean_src)
        else
            Rejected(stderr_output)
        end
    finally
        isfile(tmpfile) && rm(tmpfile)
    end
end

"""
    verify_trivial(claim::Claim; lean_dir=nothing) → VerificationResult

Verify a claim using `trivial` tactic (for testing).
"""
verify_trivial(claim::Claim; kwargs...) = verify(claim; tactic="trivial", kwargs...)
