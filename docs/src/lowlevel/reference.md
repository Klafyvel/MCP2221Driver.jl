# Low-Level API Reference

The Low-Level API commands mostly map to the HID commands supported by the chip.
In case of doubts, please refer to the [chip's documentation](https://web.archive.org/web/20240501120551/https://ww1.microchip.com/downloads/aemDocuments/documents/APID/ProductDocuments/DataSheets/MCP2221A-Data-Sheet-20005565E.pdf).

```@contents
Pages = ["reference.md"]
Depth = 4
```

## Summary of commands and responses.

```@eval
using AbstractTrees
using InteractiveUtils: subtypes, supertype
using Markdown
using MCP2221Driver
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

formattypename(t) = last(split(string(t), "."))

buf = IOBuffer()

println(buf)
println(buf, "| Command | Response |")
println(buf, "| -------:|:-------- |")
for node in AbstractTrees.PreOrderDFS(TypeTree(MCP2221Driver.AbstractCommand))
    t = nodevalue(node)
    if !isabstracttype(t)
        print(buf, "| [`$(formattypename(t))`](#$t) | ")
        if MCP2221Driver.expectsresponse(t)
            resp = MCP2221Driver.responsetype(t)
            print(buf, "[`$(formattypename(resp))`](#$resp)")
        else
            print(buf, "No response.")
        end
        println(buf, " |")
    end
end 
Markdown.parse(String(take!(buf)))
```

## Constants

```@docs
MCP2221Driver.HID_MESSAGE_LENGTH
MCP2221Driver.MCP2221A_DEFAULT_VID
MCP2221Driver.MCP2221A_DEFAULT_PID
```

## Enumerations and Utility Structures

### Communication protocol
```@docs
MCP2221Driver.ResponseStatus
MCP2221Driver.ChipConfigurationSecurityOption
```

### Analog to Digital / Ditital to Analog conversion
```@docs
MCP2221Driver.ReferenceVoltageOption
MCP2221Driver.SourceReferenceOption
```

### I²C
```@docs
MCP2221Driver.CancellationStatus
MCP2221Driver.CommunicationSpeedStatus
MCP2221Driver.I2CFrameMode
MCP2221Driver.I2CAddress
```

### General Purpose pins 
```@docs
MCP2221Driver.GPDesignation
MCP2221Driver.GPDirection
MCP2221Driver.ClockOutputDutyCycle
MCP2221Driver.ClockOutputFrequency
MCP2221Driver.GPIOStatus
```

## Commands and Responses

```@docs
MCP2221Driver.query
MCP2221Driver.GenericResponse
MCP2221Driver.StringResponse
```

### Chip configuration commands and responses

```@docs
MCP2221Driver.StatusSetParametersCommand
MCP2221Driver.StatusSetParametersResponse
MCP2221Driver.ResetChipCommand
```

#### Flash Memory Manipulation
```@docs
MCP2221Driver.ReadFlashDataCommand
MCP2221Driver.ReadFlashDataChipSettingsCommand
MCP2221Driver.ReadFlashDataChipSettingsResponse
MCP2221Driver.ReadFlashDataGPSettingsCommand
MCP2221Driver.ReadFlashDataGPSettingsResponse
MCP2221Driver.ReadFlashDataUSBManufacturerDescriptorStringCommand
MCP2221Driver.ReadFlashDataUSBProductDescriptorStringCommand
MCP2221Driver.ReadFlashDataUSBSerialNumberDescriptorStringCommand
MCP2221Driver.ReadFlashDataChipFactorySerialNumberCommand
MCP2221Driver.ReadFlashDataChipFactorySerialNumberResponse
MCP2221Driver.WriteFlashDataCommand
MCP2221Driver.WriteFlashDataChipSettingsCommand
MCP2221Driver.WriteFlashDataGPSettingsCommand
MCP2221Driver.WriteFlashStringCommand
MCP2221Driver.WriteFlashDataUSBManufacturerDescriptorStringCommand
MCP2221Driver.WriteFlashDataUSBProductDescriptorStringCommand
MCP2221Driver.WriteFlashDataUSBSerialNumberDescriptorStringCommand
MCP2221Driver.SendFlashAccessPasswordCommand
```

#### SRAM Manipulation
```@docs
MCP2221Driver.SetSRAMSettingsCommand
MCP2221Driver.GetSRAMSettingsCommand
MCP2221Driver.GetSRAMSettingsResponse
```

## I²C Communications

```@docs
MCP2221Driver.I2CWriteDataCommand
MCP2221Driver.I2CReadDataCommand
MCP2221Driver.GetI2CDataCommand
MCP2221Driver.GetI2CDataResponse
```

## GPIO Manipulation

```@docs
MCP2221Driver.SetGPIOOutputValuesCommand
MCP2221Driver.GetGPIOValuesCommand
MCP2221Driver.GetGPIOValuesResponse
```

## Index 
```@index
Pages   = ["reference.md"]
```
