using MCP2221Driver
using Test
using Aqua
using JET

@testset "MCP2221Driver.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(MCP2221Driver)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(MCP2221Driver; target_defined_modules = true)
    end
    # Write your tests here.
end
