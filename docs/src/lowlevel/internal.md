# Low-Level API internals

```@contents
Pages = ["internal.md"]
Depth = 4
```

## Communication protocol specification

The whole goal of the Low-Level API is to bridge the [chip's protocol](https://web.archive.org/web/20240501120551/https://ww1.microchip.com/downloads/aemDocuments/documents/APID/ProductDocuments/DataSheets/MCP2221A-Data-Sheet-20005565E.pdf) to arrays of bytes that can be sent through the USB. The protocol is specified using Julia's type system. This means that the API defines a set of commands that correspond to the chip's (sub-)commands[^subcommands]. The conversion to `Vector{UInt8}` is done by [`MCP2221Driver.asarray`](@ref). It initializes a 64-bytes long vector and populates the two first items using [`MCP2221Driver.commandcode`](@ref) and [`MCP2221Driver.subcommandcode`](@ref). The array is then mutated by [`MCP2221Driver.initarray!`](@ref) to correspond to the chip's specification. This allows overwriting the sub-command item for commands that do not support sub-commands (for example, [`MCP2221Driver.I2CWriteDataCommand`](@ref)).

The specification of the protocol through the type-system gives the type-stability of [`MCP2221Driver.query`](@ref). Indeed, since [`MCP2221Driver.expectsresponse`](@ref) and [`MCP2221Driver.responsetype`](@ref) are defined for each command types, the compiler knows what to expect as a response (`nothing` when `expectsresponse(T)` is `false`, `responsetype(T)` otherwise).

[^subcommands]: The chip's flash memory access commands define a set of sub-commands. For simplicity, the Low-Level API maps those as normal commands and handles internally the conversion to sub-commands. Some commands have also been grouped, such as the I²C writing commands.

## Low-Level API internals Reference

### Commands and Responses

```@docs
MCP2221Driver.AbstractCommand
MCP2221Driver.AbstractResponse
```

### [Command interface](@id midlevel_command_interface)
```@docs
MCP2221Driver.asarray
MCP2221Driver.commandcode
MCP2221Driver.subcommandcode
MCP2221Driver.responsetype
MCP2221Driver.expectsresponse
MCP2221Driver.initarray!
```

### Utilities

```@docs
MCP2221Driver.ByteStringIterator
MCP2221Driver.CommandSummary
MCP2221Driver.writeaddress
MCP2221Driver.readaddress
```

### Index
```@index
Pages   = ["internal.md"]
```

