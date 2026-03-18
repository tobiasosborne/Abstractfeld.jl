@testset "Structural hashing" begin
    @testset "deterministic" begin
        e = app(:+, lit(1), lit(2))
        h1 = structural_hash(e)
        h2 = structural_hash(e)
        @test h1 == h2
        @test length(h1) == 64  # SHA-256 hex = 64 chars
    end

    @testset "different exprs → different hashes" begin
        e1 = app(:+, lit(1), lit(2))
        e2 = app(:+, lit(1), lit(3))
        @test structural_hash(e1) != structural_hash(e2)
    end

    @testset "equal exprs → same hash" begin
        e1 = tensor(:R, idx(:a, Down), idx(:b, Down))
        e2 = tensor(:R, idx(:a, Down), idx(:b, Down))
        @test structural_hash(e1) == structural_hash(e2)
    end
end
