# MCP2221Driver

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://klafyvel.github.io/MCP2221Driver.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://klafyvel.github.io/MCP2221Driver.jl/dev/)
[![Build Status](https://github.com/klafyvel/MCP2221Driver.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/klafyvel/MCP2221Driver.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

`MCP2221Driver.jl` is a driver to use Microship's MCP2221 hardware through HidApi. This enables I²C communications, GPIO operations, and analog IO operations directly from Julia using this hardware. For now, only the low-level API is available.

## Installation

The package can be installed throug the package manager:

```julia
]add MCP2221Driver
```

## Example

See [the tutorial](https://klafyvel.github.io/MCP2221Driver.jl/dev/lowlevel/tutorial) for more in-depth usage examples. Here is an example blink program:

```julia
using MCP2221Driver
import HidApi
HidApi.init()

device = open(HidApi.find_device(
    MCP2221Driver.MCP2221A_DEFAULT_VID, 
    MCP2221Driver.MCP2221A_DEFAULT_PID
))

# Configuring pins for GPIO operations
command = MCP2221Driver.GetSRAMSettingsCommand()
response = MCP2221Driver.query(device, command)
command = MCP2221Driver.SetSRAMSettingsCommand(
    gpiosettings=(
        gpio0=response.gpio0status, 
        gpio1=response.gpio1status, 
        gpio2=MCP2221Driver.GPIOStatus(false, 
                                       MCP2221Driver.GPIOOutput, 
                                       MCP2221Driver.GPIOOperation
                                       ), 
        gpio3=MCP2221Driver.GPIOStatus(false, 
                                       MCP2221Driver.GPIOOutput, 
                                       MCP2221Driver.GPIOOperation
                                       )
    )
)
MCP2221Driver.query(device, command)

# Actual blinking
for i in 1:60
    command = MCP2221Driver.SetGPIOOutputValuesCommand(gp2outputvalue=isodd(i), gp3outputvalue=iseven(i))
    MCP2221Driver.query(device, command)
    sleep(1)
end

close(device)
HidApi.shutdown()

```
