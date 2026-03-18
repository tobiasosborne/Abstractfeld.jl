@testset "IR types" begin
    @testset "constructors" begin
        # Lit
        @test lit(1).val == 1//1
        @test lit(3//4).val == 3//4

        # Sym
        @test sym(:x).name == :x
        @test sym("y").name == :y

        # Idx
        @test idx(:a, Down).name == :a
        @test idx(:a, Down).pos == Down
        @test idx("b", Up).pos == Up

        # App
        e = app(:+, lit(1), lit(2))
        @test e.op == :+
        @test length(e.args) == 2

        # Bind  — ∫₀^∞ e^{-px} dx
        integral = bnd(:int, sym(:x),
            app(:exp, app(:neg, app(:*, sym(:p), sym(:x)))),
            lit(0), sym(:inf))
        @test integral.binder == :int
        @test integral.var == sym(:x)
        @test length(integral.metadata) == 2

        # Ann
        e_ann = ann(sym(:T), SymmetryAnn(:antisym, [1, 2]))
        @test e_ann.expr == sym(:T)
        @test e_ann.ann isa SymmetryAnn

        # tensor convenience
        R = tensor(:R, idx(:a, Down), idx(:b, Down), idx(:c, Down), idx(:d, Down))
        @test R.op == :tensor
        @test length(R.args) == 5  # name + 4 indices
        @test R.args[1] == sym(:R)
    end

    @testset "equality and hashing" begin
        e1 = app(:+, lit(1), lit(2))
        e2 = app(:+, lit(1), lit(2))
        e3 = app(:+, lit(1), lit(3))
        @test e1 == e2
        @test e1 != e3
        @test hash(e1) == hash(e2)
        @test hash(e1) != hash(e3)  # probabilistic, but safe for these

        # Different types never equal
        @test lit(1) != sym(:x)
        @test sym(:x) != idx(:x, Up)

        # Annotation equality
        @test SymmetryAnn(:antisym, [1,2]) == SymmetryAnn(:antisym, [1,2])
        @test SymmetryAnn(:antisym, [1,2]) != SymmetryAnn(:sym, [1,2])
        @test TypeAnn(:real) == TypeAnn(:real)
    end

    @testset "representative expressions" begin
        # R_{abcd}
        R_abcd = tensor(:R, idx(:a, Down), idx(:b, Down), idx(:c, Down), idx(:d, Down))
        @test R_abcd isa App

        # ∫₀^∞ e^{-px} dx
        integral = bnd(:int, sym(:x),
            app(:exp, app(:neg, app(:*, sym(:p), sym(:x)))),
            lit(0), sym(:inf))
        @test integral isa Bind

        # x + y * z
        poly = app(:+, sym(:x), app(:*, sym(:y), sym(:z)))
        @test poly isa App
    end
end
