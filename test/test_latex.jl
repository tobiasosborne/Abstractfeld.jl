@testset "LaTeX renderer" begin
    @testset "basic expressions" begin
        @test render_latex(lit(42)) == "42"
        @test render_latex(lit(-3)) == "{-3}"
        @test render_latex(lit(3//4)) == "\\frac{3}{4}"
        @test render_latex(sym(:x)) == "x"
        @test render_latex(sym(:alpha)) == "\\alpha"
    end

    @testset "tensor expressions" begin
        R = tensor(:R, idx(:a, Down), idx(:b, Down))
        @test render_latex(R) == "R_{ab}"

        R4 = tensor(:R, idx(:a, Down), idx(:b, Down), idx(:c, Down), idx(:d, Down))
        @test render_latex(R4) == "R_{abcd}"

        # Mixed up/down
        T = tensor(:T, idx(:mu, Up), idx(:nu, Down))
        @test render_latex(T) == "T_{\\nu}^{\\mu}"
    end

    @testset "arithmetic" begin
        @test render_latex(app(:+, sym(:x), sym(:y))) == "x + y"
        @test render_latex(app(:+, sym(:x), app(:*, lit(2), sym(:y)))) == "x + 2 y"
        @test render_latex(app(:/, sym(:x), sym(:y))) == "\\frac{x}{y}"
        @test render_latex(app(:^, sym(:x), lit(2))) == "x^{2}"
    end

    @testset "special functions" begin
        @test render_latex(app(:exp, sym(:x))) == "e^{x}"
        @test render_latex(app(:sqrt, sym(:x))) == "\\sqrt{x}"
    end

    @testset "integrals" begin
        # ∫₀^∞ e^{-px} dx
        integral = bnd(:int, sym(:x),
            app(:exp, app(:neg, app(:*, sym(:p), sym(:x)))),
            lit(0), sym(:inf))
        @test render_latex(integral) == "\\int_{0}^{\\infty} e^{-\\left(p x\\right)} \\, dx"
    end

    @testset "annotations are transparent" begin
        e = ann(sym(:x), TypeAnn(:real))
        @test render_latex(e) == "x"
    end
end
