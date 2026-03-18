using Test
using Abstractfeld

@testset "Abstractfeld" begin
    include("test_ir.jl")
    include("test_sexpr.jl")
    include("test_canonical.jl")
    include("test_json.jl")
    include("test_latex.jl")
    include("test_terminterface.jl")
    include("test_roundtrip.jl")
    include("test_egraph.jl")
    include("test_pipeline.jl")
end
