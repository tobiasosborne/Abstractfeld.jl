@testset "S-expression serialization" begin
    @testset "to_sexpr" begin
        @test to_sexpr(lit(42)) == "(lit 42)"
        @test to_sexpr(lit(3//4)) == "(lit 3/4)"
        @test to_sexpr(sym(:x)) == "(sym x)"
        @test to_sexpr(idx(:a, Down)) == "(idx a down)"
        @test to_sexpr(idx(:b, Up)) == "(idx b up)"
        @test to_sexpr(app(:+, lit(1), lit(2))) == "(app + (lit 1) (lit 2))"

        # R_{abcd}
        R = tensor(:R, idx(:a, Down), idx(:b, Down), idx(:c, Down), idx(:d, Down))
        @test to_sexpr(R) == "(app tensor (sym R) (idx a down) (idx b down) (idx c down) (idx d down))"

        # Bind: ∫₀^∞ e^{-px} dx
        integral = bnd(:int, sym(:x),
            app(:exp, app(:neg, app(:*, sym(:p), sym(:x)))),
            lit(0), sym(:inf))
        expected = "(bind int (sym x) (app exp (app neg (app * (sym p) (sym x)))) (lit 0) (sym inf))"
        @test to_sexpr(integral) == expected

        # Annotation
        e = ann(sym(:T), SymmetryAnn(:antisym, [1, 2]))
        @test to_sexpr(e) == "(ann (sym T) (symmetry antisym 1 2))"

        e2 = ann(sym(:x), TypeAnn(:real))
        @test to_sexpr(e2) == "(ann (sym x) (type real))"
    end

    @testset "parse_sexpr" begin
        @test parse_sexpr("(lit 42)") == lit(42)
        @test parse_sexpr("(lit 3/4)") == lit(3//4)
        @test parse_sexpr("(sym x)") == sym(:x)
        @test parse_sexpr("(idx a down)") == idx(:a, Down)
        @test parse_sexpr("(app + (lit 1) (lit 2))") == app(:+, lit(1), lit(2))
    end

    @testset "round-trip" begin
        exprs = [
            lit(0),
            lit(1),
            lit(-7//3),
            sym(:x),
            idx(:mu, Up),
            idx(:a, Down),
            app(:+, lit(1), lit(2)),
            app(:*, sym(:x), sym(:y), sym(:z)),
            tensor(:R, idx(:a, Down), idx(:b, Down), idx(:c, Down), idx(:d, Down)),
            bnd(:int, sym(:x),
                app(:exp, app(:neg, app(:*, sym(:p), sym(:x)))),
                lit(0), sym(:inf)),
            ann(sym(:T), SymmetryAnn(:antisym, [1, 2, 3])),
            ann(lit(0), TypeAnn(:real)),
            # Nested
            app(:+, app(:*, lit(2), sym(:x)), app(:*, lit(3), sym(:y))),
        ]

        for e in exprs
            s = to_sexpr(e)
            e2 = parse_sexpr(s)
            @test e2 == e
            # Canonical: re-serializing gives the same string
            @test to_sexpr(e2) == s
        end
    end

    @testset "parse errors" begin
        @test_throws Abstractfeld.ParseError parse_sexpr("")
        @test_throws Abstractfeld.ParseError parse_sexpr("(foo 1)")
        @test_throws Abstractfeld.ParseError parse_sexpr("(lit 1) extra")
        @test_throws Abstractfeld.ParseError parse_sexpr("(idx a sideways)")
    end
end
