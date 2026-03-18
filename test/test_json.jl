@testset "JSON serialization" begin
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
            app(:+, app(:*, lit(2), sym(:x)), app(:*, lit(3), sym(:y))),
        ]

        for e in exprs
            j = to_json(e)
            e2 = from_json(j)
            @test e2 == e
        end
    end
end
