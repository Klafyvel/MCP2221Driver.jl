#!/usr/bin/env -S julia --color=yes --startup-file=no
using LiveServer
using Pkg

function livedoc()
    Pkg.activate("docs")    
    Pkg.develop(PackageSpec(path=pwd()))
    Pkg.instantiate()
    servedocs()
end

function showhelp(io=stdout)
    printstyled(io, "NAME", bold = true)
    println(io)
    println(io, "       develop.main - Some utilities to develop MCP2221Driver.jl")
    println(io)
    printstyled(io, "SYNOPSIS", bold = true)
    println(io)
    println(io, "       julia develop.jl <command>")
    println(io)
    printstyled(io, "COMMANDS", bold = true)
    println(io)
    println(
        io, """
               livedoc
                   Build and serve documentation using LiveServer.jl (needs to be installed).
               help
                   Print this message.
        """)
    return
end

function main(arguments)
    if isempty(arguments) || first(arguments) == "help"
        showhelp()
    elseif first(arguments) == "livedoc"
        livedoc()
    else
        showhelp()
    end
end

@isdefined(var"@main") ? (@main) : exit(main(ARGS)) 
