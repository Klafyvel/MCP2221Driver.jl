using MCP2221Driver
using Documenter

DocMeta.setdocmeta!(MCP2221Driver, :DocTestSetup, :(using MCP2221Driver); recursive=true)

makedocs(;
    modules=[MCP2221Driver],
    authors="Hugo Levy-Falk <hugo@klafyvel.me> and contributors",
    sitename="MCP2221Driver.jl",
    format=Documenter.HTML(;
        canonical="https://klafyvel.github.io/MCP2221Driver.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/klafyvel/MCP2221Driver.jl",
    devbranch="main",
)
