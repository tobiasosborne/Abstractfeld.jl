using TermInterface

@testset "TermInterface protocol" begin
    @testset "App nodes" begin
        e = app(:+, lit(1), lit(2))
        @test iscall(e) == true
        @test operation(e) == :+
        @test arguments(e) == [lit(1), lit(2)]
        @test head(e) == :+
        @test children(e) == [lit(1), lit(2)]

        # Reconstruct via maketerm
        e2 = maketerm(App, :+, [lit(1), lit(2)])
        @test e2 == e
    end

    @testset "Bind nodes" begin
        e = bnd(:int, sym(:x), app(:exp, sym(:x)), lit(0), sym(:inf))
        @test iscall(e) == true
        @test operation(e) == :int
        ch = children(e)
        @test ch[1] == sym(:x)  # var
        @test ch[2] == app(:exp, sym(:x))  # body
        @test ch[3] == lit(0)  # metadata[1]
        @test ch[4] == sym(:inf)  # metadata[2]

        # Reconstruct via maketerm
        e2 = maketerm(Bind, :int, ch)
        @test e2 == e
    end

    @testset "Leaf nodes" begin
        @test iscall(lit(1)) == false
        @test iscall(sym(:x)) == false
        @test iscall(idx(:a, Down)) == false
    end

    @testset "Nested App reconstruction" begin
        e = app(:+, app(:*, lit(2), sym(:x)), app(:*, lit(3), sym(:y)))
        # Replace first argument
        new_args = [app(:*, lit(5), sym(:x)), arguments(e)[2]]
        e2 = maketerm(App, operation(e), new_args)
        @test e2 == app(:+, app(:*, lit(5), sym(:x)), app(:*, lit(3), sym(:y)))
    end
end
