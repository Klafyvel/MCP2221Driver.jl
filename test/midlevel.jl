# There are many types here we want to test, but they are all subtypes of
# AbstractCommand and AbstractResponse, so... a tree structure.
# We need to use a typewrapper because defining childrentype on Type directly fails.
struct TypeTree
    t::Type
end
function AbstractTrees.children(t::TypeTree)
    return t.t === Function ? Vector{TypeTree}() : map(x -> TypeTree(x), filter(x -> x !== Any, subtypes(t.t)))
end
AbstractTrees.printnode(io::IO, t::TypeTree) = print(io, t.t)
AbstractTrees.nodevalue(t::TypeTree) = t.t
AbstractTrees.parent(t::TypeTree) = TypeTree(supertype(t.t))
AbstractTrees.ParentLinks(::Type{TypeTree}) = StoredParents()

function test_command_type(commandtype)
    # Commands should be an acceptable input for commandcode
    @test hasmethod(MCP2221Driver.commandcode, Tuple{commandtype})
    @test hasmethod(MCP2221Driver.subcommandcode, Tuple{commandtype})
    if MCP2221Driver.expectsresponse(commandtype)
        # Commands types should be an acceptable input for responsetype
        @test hasmethod(MCP2221Driver.responsetype, Tuple{Type{commandtype}})
        # responsetype should answer a type derived from AbstractResponse
        @test MCP2221Driver.responsetype(commandtype) <: MCP2221Driver.AbstractResponse
    end
    # Commands should be an acceptable input for initarray!
    return @test hasmethod(MCP2221Driver.initarray!, Tuple{commandtype, Vector{UInt8}})
end

function test_response_type(responsetype)
    # Responses types should define a status
    @test hasfield(responsetype, :status)
    # Responses types should be able to build from a Vector{UInt8}
    @test hasmethod(responsetype, Tuple{Vector{UInt8}})
    # Poor man's errors check: try to build the response from zeros
    v = zeros(UInt8, 64)
    return @test typeof(responsetype(v)) == responsetype
end

@testset "midlevel API" begin
    @testset "Response type $(responsetype) definition" for responsetype in nodevalue.(AbstractTrees.Leaves(TypeTree(MCP2221Driver.AbstractResponse)))
        test_response_type(responsetype)
    end
    @testset "Command type $(commandtype) definition" for commandtype in nodevalue.(AbstractTrees.Leaves(TypeTree(MCP2221Driver.AbstractCommand)))
        test_command_type(commandtype)
    end
end
