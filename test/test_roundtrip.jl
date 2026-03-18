@testset "Julia↔Lean round-trip" begin
    # Test corpus covering all 6 IR node types
    exprs = [
        # Lit
        lit(0),
        lit(42),
        lit(-7//3),
        lit(1//1000000),
        # Sym
        sym(:x),
        sym(:alpha),
        # Idx
        idx(:a, Down),
        idx(:mu, Up),
        # App (nested)
        app(:+, lit(1), lit(2)),
        app(:*, sym(:x), sym(:y), sym(:z)),
        app(:+, app(:*, lit(2), sym(:x)), app(:*, lit(3), sym(:y))),
        # Tensor (special app)
        tensor(:R, idx(:a, Down), idx(:b, Down), idx(:c, Down), idx(:d, Down)),
        # Bind (integral)
        bnd(:int, sym(:x),
            app(:exp, app(:neg, app(:*, sym(:p), sym(:x)))),
            lit(0), sym(:inf)),
        # Ann
        ann(sym(:T), SymmetryAnn(:antisym, [1, 2, 3])),
        ann(lit(0), TypeAnn(:real)),
    ]

    lean_exe = joinpath(@__DIR__, "..", "lean", ".lake", "build", "bin", "roundtrip")

    if !isfile(lean_exe)
        @warn "Lean roundtrip executable not found at $lean_exe — skipping"
        return
    end

    # Send all expressions as JSON lines, get back JSON lines
    input = join([to_json(e) for e in exprs], "\n") * "\n"

    output = read(pipeline(`echo $input`, `$lean_exe`), String)
    result_lines = filter(!isempty, split(output, "\n"))

    @test length(result_lines) == length(exprs)

    for (i, (orig, line)) in enumerate(zip(exprs, result_lines))
        roundtripped = from_json(String(line))
        @test roundtripped == orig
    end
end
