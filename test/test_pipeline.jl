@testset "End-to-end pipeline" begin
    @testset "E-graph → Claim → Numerical verify → KB store" begin
        # Step 1: E-graph saturation discovers x+y ≡ y+x
        theory = @slots a b @theory begin a + b == b + a end
        e1 = app(:+, sym(:x), sym(:y))
        e2 = app(:+, sym(:y), sym(:x))
        @test equivalent(e1, e2, theory)

        # Step 2: Create claim
        claim = make_claim(e1, e2; rules=[:commutativity])
        @test claim.lhs == e1
        @test claim.rhs == e2

        # Step 3: Numerical pre-filter (L2 verification)
        @test verify_claim_numerically(claim)

        # Step 4: Store in KB at L3 (CAS-checked)
        kb = create_kb()
        vr = VerifiedResult(claim, 3, "", :egraph)
        id = store!(kb, vr)
        @test id > 0

        # Step 5: Query KB
        result = lookup_claim(kb, e1, e2)
        @test !isnothing(result)
        @test result.level == 3

        # Step 6: Upgrade to L4 (Lean-verified)
        store!(kb, VerifiedResult(claim, 4, "by simp [add_comm]", :lean))
        result2 = lookup_claim(kb, e1, e2)
        @test result2.level == 4
        @test has_claim(kb, e1, e2; min_level=4)

        # Step 7: Check KB stats
        stats = kb_stats(kb)
        @test stats.total == 1
        @test stats.l4 == 1

        close_kb!(kb)
    end

    @testset "Lean verification orchestrator" begin
        # Trivial claim compiles
        c = make_claim(lit(0), lit(0))
        result = verify_trivial(c)
        @test result isa Verified

        # Sorry-based claim compiles
        c2 = make_claim(sym(:x), sym(:y))
        result2 = verify(c2; tactic="sorry")
        @test result2 isa Verified
    end

    @testset "Prompt generation" begin
        claim = make_claim(
            app(:+, sym(:R_abcd), sym(:R_abdc)), lit(0);
            rules=[:antisym_swap])
        prompt = format_prompt(claim;
            hint_lemmas=["AlternatingMap.map_swap"])
        @test occursin("AlternatingMap.map_swap", prompt)
        @test occursin("R_abcd", prompt)
        @test occursin("tactic", prompt)
    end

    @testset "Tactic parsing" begin
        @test parse_tactic_block("by simp") == "by simp"
        @test parse_tactic_block("```lean\nby ring\n```") == "by ring"
        @test parse_tactic_block("omega") == "by\n  omega"
        @test parse_tactic_block("") === nothing
        @test parse_tactic_block("random text without tactics") === nothing
    end

    @testset "KB deduplication" begin
        kb = create_kb()
        c = make_claim(sym(:a), sym(:a))

        id1 = store!(kb, VerifiedResult(c, 1, "", :manual))
        id2 = store!(kb, VerifiedResult(c, 1, "", :manual))
        @test id1 == id2  # dedup by hash

        id3 = store!(kb, VerifiedResult(c, 4, "by rfl", :lean))
        @test id3 == id1  # same entry, upgraded
        @test lookup_claim(kb, sym(:a), sym(:a)).level == 4

        @test kb_stats(kb).total == 1

        close_kb!(kb)
    end

    @testset "Full tensor algebra theory" begin
        t = tensor_algebra()
        @test length(t) == 11

        # Commutativity + associativity combined
        e1 = app(:+, app(:+, sym(:a), sym(:b)), sym(:c))
        e2 = app(:+, sym(:c), app(:+, sym(:b), sym(:a)))
        @test equivalent(e1, e2, t)
    end
end
