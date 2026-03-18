@testset "E-graph saturation" begin
    @testset "basic EGraph construction" begin
        e = app(:+, sym(:x), sym(:y))
        g = EGraph(e)
        @test length(g.classes) == 3  # x, y, x+y
    end

    @testset "commutativity via saturation" begin
        e1 = app(:+, sym(:x), sym(:y))
        e2 = app(:+, sym(:y), sym(:x))
        t = @slots a b @theory begin a + b == b + a end
        result = saturate_expr(e1, t)
        @test result.reason == :saturated
        @test result.num_eclasses == 3
        @test equivalent(e1, e2, t)
    end

    @testset "associativity via saturation" begin
        e1 = app(:+, app(:+, sym(:x), sym(:y)), sym(:z))
        e2 = app(:+, sym(:x), app(:+, sym(:y), sym(:z)))
        t = @slots a b c @theory begin (a + b) + c == a + (b + c) end
        @test equivalent(e1, e2, t)
    end

    @testset "tensor_algebra theory loads" begin
        t = tensor_algebra()
        @test length(t) == 11
    end

    @testset "extraction produces valid IR" begin
        e = app(:+, sym(:x), sym(:y))
        result = saturate_expr(e, tensor_algebra())
        extracted = extract_best(result)
        @test extracted isa App
        @test extracted.op == :+
    end
end

@testset "Numerical pre-filter" begin
    @testset "true identities" begin
        @test numerical_check(app(:+, sym(:x), sym(:y)),
                              app(:+, sym(:y), sym(:x)))
        @test numerical_check(lit(0), lit(0))
        @test numerical_check(app(:*, lit(2), sym(:x)),
                              app(:+, sym(:x), sym(:x)))
    end

    @testset "false identities" begin
        @test !numerical_check(app(:+, sym(:x), sym(:y)),
                               app(:*, sym(:x), sym(:y)))
        @test !numerical_check(lit(1), lit(2))
    end

    @testset "fingerprint determinism" begin
        e = app(:+, sym(:x), app(:*, lit(3), sym(:y)))
        fp1 = numerical_fingerprint(e)
        fp2 = numerical_fingerprint(e)
        @test fp1 == fp2
        @test length(fp1) == 32  # SHA-256

        # Different expressions should (almost certainly) have different fingerprints
        fp3 = numerical_fingerprint(app(:*, sym(:x), sym(:y)))
        @test fp1 != fp3
    end

    @testset "eval_numerical" begin
        bindings = Dict{Symbol,Rational{BigInt}}(:x => 3//1, :y => 5//1)
        @test eval_numerical(lit(42), bindings) == 42
        @test eval_numerical(sym(:x), bindings) == 3
        @test eval_numerical(app(:+, sym(:x), sym(:y)), bindings) == 8
        @test eval_numerical(app(:*, sym(:x), sym(:y)), bindings) == 15
        @test eval_numerical(app(:neg, sym(:x)), bindings) == -3
    end

    @testset "free_syms" begin
        e = app(:+, sym(:x), app(:*, sym(:y), sym(:z)))
        @test free_syms(e) == Set([:x, :y, :z])
        @test free_syms(lit(42)) == Set{Symbol}()
    end
end
