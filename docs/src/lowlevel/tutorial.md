# Low-Level API Tutorial

This tutorial aims at guiding you through the basic usage of the Low-Level API. 
In case of doubts, please refer to the [chip's documentation](https://web.archive.org/web/20240501120551/https://ww1.microchip.com/downloads/aemDocuments/documents/APID/ProductDocuments/DataSheets/MCP2221A-Data-Sheet-20005565E.pdf). It assumes that you have a MCP2221A device connected through the USB.

!!! warning "Follow at your own risks"
    When dealing with hardware components and USB devices, it is possible to 
    damage your computer or your devices. It is also possible to brick your device
    (especially if you use the password settings of the MCP2221A). While I have
    tested this tutorial at the time of writing it, I decline all responsibilities
    for what may happen if you follow it. Use at your own risks!


```@contents
Pages = ["tutorial.md"]
Depth = 4
```

## Connecting to the hardware

The Low-Level API expects you to provide a device to which it can talk to. In this tutorial, we are going to use [HidApi.jl](https://github.com/laborg/HidApi.jl) to connect to and handle the USB communications to the hardware. You can install it using:

```julia-repl
julia> import Pkg
julia> Pkg.add("HidApi")
```

HidApi.jl requires initialization before it lets us enumerate devices:

```julia-repl
julia> using HidApi, MCP2221Driver

julia> init()

julia> devices = enumerate_devices()
2-element Vector{HidDevice}:
 HidDevice("1-1:1.2", 0x04d8, 0x00dd, "", 0x0100, "", "", 0x0000, 0x0000, 2, Ptr{HidApi.hid_device_} @0x0000000000000000, HidApi.hid_device_info(Ptr{Int8} @0x0000000004cccfa0, 0x04d8, 0x00dd, Ptr{Nothing} @0x0000000000000000, 0x0100, Ptr{Nothing} @0x0000000000000000, Ptr{Nothing} @0x0000000000000000, 0x0000, 0x0000, 2, Ptr{HidApi.hid_device_info} @0x0000000004312c60, HidApi.HID_API_BUS_USB))
... Other devices if some are present.
```

For this tutorial, I am using a brand new MCP2221A that hasn't been used yet. The chip's documentation gives the default Vendor ID (`0x04D8`) and Product ID (`0x00DD`). They can also be found in [`MCP2221Driver.MCP2221A_DEFAULT_VID`](@ref) and [`MCP2221Driver.MCP2221A_DEFAULT_PID`](@ref). 

!!! note "Linux users and permissions"
    At this point, Linux users may not be able to connect to their device. You can fix this by creating a [udev rule](https://wiki.archlinux.org/title/Udev) for our MCP2221A chip. For example, the following rule (to be added in file `/etc/udev/rules.d/50-mcp2221a-tutorial.rules`) will allow you to connect to the chip:
    ```udev
    SUBSYSTEM=="usb", ATTR{idVendor}=="04d8", ATTR{idProduct}=="00dd", MODE:="0666"
    ```
    Then, you can reload udev rules and trigger them with 
    ```bash
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    ```
    Be aware that you will need to repeat the operation later-on if you change the Vendor ID or Product ID of the chip. 

We can connect using HidApi.jl's `find_device` function.
```julia-repl
julia> device = open(find_device(MCP2221Driver.MCP2221A_DEFAULT_VID, MCP2221Driver.MCP2221A_DEFAULT_PID))
Vendor/Product ID : 0x04d8 / 0x00dd
             Path : 1-1:1.2
          Product : MCP2221 USB-I2C/UART Combo
    Serial number : 
     Manufacturer : Microchip Technology Inc.

```

!!! note "Leaving properly"
    Remember to close the device and HidApi.jl when you leave the REPL to avoid running into problems!
    ```julia-repl
    julia> close(device)
    Vendor/Product ID : 0x04d8 / 0x00dd
                 Path : 1-1:1.2
              Product : MCP2221 USB-I2C/UART Combo
        Serial number : 
         Manufacturer : Microchip Technology Inc.

    julia> shutdown()
    ```

## Some simple queries

At this stage, you should have your device loaded in the REPL and open. We can start by querying the current state of the chip. To do so, we use the [`MCP2221Driver.StatusSetParametersCommand`](@ref) command:
```julia-repl
julia> command = MCP2221Driver.StatusSetParametersCommand(false, 0x00)
MCP2221Driver.StatusSetParametersCommand(false, 0)

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.StatusSetParametersResponse(MCP2221Driver.Success, MCP2221Driver.NoSpecialOperation, MCP2221Driver.NoSetSpeed, 0x00, 0x0000, 0x0000, 0x00, 0x00, 0x00, 0x0000, false, 0x01, 0x01, false, 0x00, v"65.54.0", v"49.50.0", 0x03ff, 0x0000, 0x0300)
```

The chip gives us a set of its current parameters. Refer to [`MCP2221Driver.StatusSetParametersResponse`](@ref)'s documentation to get their meaning. For example, one can see that my chip uses the following hardware and firmware versions:
```julia-repl
julia> response.hardwareversion
v"65.54.0"

julia> response.firmwareversion
v"49.50.0"
```

Refer to the [Low-Level API Reference](@ref) to get a list of available commands. For example, we can query the current state of the GPIO pins:
```julia-repl
julia> command = MCP2221Driver.GetGPIOValuesCommand()
MCP2221Driver.GetGPIOValuesCommand()

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GetGPIOValuesResponse(MCP2221Driver.Success, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
```

[`MCP2221Driver.GetGPIOValuesResponse`](@ref) tells us that all these `nothing` means that none of the GPIO pin is configured to be used as a GPIO. Indeed, if we query the current SRAM settings, we get:
```julia-repl
julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GetSRAMSettingsResponse(MCP2221Driver.Success, 0x12, 0x04, false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput12MHz, MCP2221Driver.Reference2p048, MCP2221Driver.SourceReferenceVDD, 0x08, true, true, MCP2221Driver.Reference1p024, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32, "\0\0\0\0\0\0\0\0", MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation))

julia> response.gpio0status
MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0)

julia> response.gpio1status
MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1)

julia> response.gpio2status
MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation)

julia> response.gpio3status
MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation)

```

All GPIO pins are dedicated to functions other than GPIO operations. See [`MCP2221Driver.GPDesignation`](@ref) for the meaning of these.

## Chip settings

We have already used [`MCP2221Driver.GetSRAMSettingsCommand`](@ref) to query the currently loaded settings. At boot, the MCP2221A loads the settings present in flash memory to SRAM. We can confirm that both flash settings and SRAM settings match. Note that flash memory settings are separated in several commands, see the [Flash Memory Manipulation](@ref) section of the [Low-Level API Reference](@ref) for a list.

```julia-repl
julia> command = MCP2221Driver.ReadFlashDataChipSettingsCommand()
MCP2221Driver.ReadFlashDataChipSettingsCommand()

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.ReadFlashDataChipSettingsResponse(MCP2221Driver.Success, false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput12MHz, MCP2221Driver.Reference2p048, MCP2221Driver.SourceReferenceVDD, 0x08, true, true, MCP2221Driver.Reference4p096, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32)

```

For example, the current clock output setting is set for 12 MHz output:
```julia-repl
julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command);

julia> response.clockoutputdividervalue
ClockOutput12MHz::ClockOutputFrequency = 0x02
```

We can change that using [`MCP2221Driver.SetSRAMSettingsCommand`](@ref):
```julia-repl
julia> command = MCP2221Driver.SetSRAMSettingsCommand(clockoutputsettings=(duty=MCP2221Driver.ClockOutputDuty50, dividervalue=MCP2221Driver.ClockOutput3MHz))
MCP2221Driver.SetSRAMSettingsCommand((duty = MCP2221Driver.ClockOutputDuty50, dividervalue = MCP2221Driver.ClockOutput3MHz), nothing, nothing, nothing, nothing, nothing, false, nothing)

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GenericResponse(MCP2221Driver.Success)

```

We can check that the clock output frequency has indeed been modified:
```julia-repl
julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command);

julia> response.clockoutputdividervalue
ClockOutput3MHz::ClockOutputFrequency = 0x04

```

However, if you power-down your device, this modification gets erased:
```julia-repl
julia> close(device)
Vendor/Product ID : 0x04d8 / 0x00dd
             Path : 1-1:1.2
          Product : MCP2221 USB-I2C/UART Combo
    Serial number : 
     Manufacturer : Microchip Technology Inc.

# Here, un-plug then re-plug the USB

julia> device = open(find_device(MCP2221Driver.MCP2221A_DEFAULT_VID, MCP2221Driver.MCP2221A_DEFAULT_PID))
Vendor/Product ID : 0x04d8 / 0x00dd
             Path : 1-1:1.2
          Product : MCP2221 USB-I2C/UART Combo
    Serial number : 
     Manufacturer : Microchip Technology Inc.

julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GetSRAMSettingsResponse(MCP2221Driver.Success, 0x12, 0x04, false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput12MHz, MCP2221Driver.Reference2p048, MCP2221Driver.SourceReferenceVDD, 0x08, true, true, MCP2221Driver.Reference1p024, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32, "\0\0\0\0\0\0\0\0", MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation))

julia> response.clockoutputdividervalue
ClockOutput12MHz::ClockOutputFrequency = 0x02
```

To make te change persistent after reboots, one needs to write this into flash memory. This is a bit tedious to do with the low-level API, as you need to re-send all the other parameters affected by the flash writing command you use.

```julia-repl
julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command);

julia> command = MCP2221Driver.WriteFlashDataChipSettingsCommand(
       response.cdcserialnumberenumerationenable,
       response.chipconfigurationsecurityoption,
       response.clockoutputduty,
       MCP2221Driver.ClockOutput3MHz,
       response.dacreferencevoltage,
       response.dacreferenceoption,
       response.powerupdacvalue,
       response.interruptdetectionnegativeedge,
       response.interruptdetectionpositiveedge,
       response.adcreferencevoltage,
       response.adcreferenceoption,
       response.vid,
       response.pid,
       response.usbpowerattributes,
       response.usbrequestednumberofma,
       ""
       )
MCP2221Driver.WriteFlashDataChipSettingsCommand(false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput3MHz, MCP2221Driver.Reference2p048, MCP2221Driver.SourceReferenceVDD, 0x08, true, true, MCP2221Driver.Reference1p024, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32, "")

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GenericResponse(MCP2221Driver.Success)
```

!!! note "Password protection"
    Please, note that here the device is not password-protected, hence I can supply an empty password as the last parameter of the command. Please refer to the chip manual and the [Low-Level API Reference](@ref) concerning password protection.

If you now close the device (`close(device)`), un-plug and re-plug it, then do:

```julia-repl
julia> device = open(find_device(MCP2221Driver.MCP2221A_DEFAULT_VID, MCP2221Driver.MCP2221A_DEFAULT_PID))
Vendor/Product ID : 0x04d8 / 0x00dd
             Path : 1-1:1.2
          Product : MCP2221 USB-I2C/UART Combo
    Serial number : 
     Manufacturer : Microchip Technology Inc.

julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command);

julia> response.clockoutputdividervalue
ClockOutput3MHz::ClockOutputFrequency = 0x04

```

You can see that we have made the change persistent!

## GPIO Operations

In this section, we illustrate the use GPIO pins 2 and 3 to write a "blink" program.

The first step is to configure the two pins as outputs. We will also set their output value to 0. This is done with the [`MCP2221Driver.SetSRAMSettingsCommand`](@ref) command. We have to send configuration for all four GP pins, so we first retrieve the configuration for the two other pins.

```julia-repl
julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GetSRAMSettingsResponse(MCP2221Driver.Success, 0x12, 0x04, false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput3MHz, MCP2221Driver.Reference2p048, MCP2221Driver.SourceReferenceVRM, 0x00, true, true, MCP2221Driver.Reference1p024, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32, "\0\0\0\0\0\0\0\0", MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation))

julia> response.gpio2status
MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation)

julia> response.gpio3status
MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.DedicatedFunctionOperation)

julia> command = MCP2221Driver.SetSRAMSettingsCommand(gpiosettings=(gpio0=response.gpio0status, gpio1=response.gpio1status, gpio2=MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation), gpio3=MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation)))
MCP2221Driver.SetSRAMSettingsCommand(nothing, nothing, nothing, nothing, nothing, nothing, false, (gpio0 = MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), gpio1 = MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), gpio2 = MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation), gpio3 = MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation)))

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GenericResponse(MCP2221Driver.Success)

```

We could keep using the same command to make the outputs blink, but we can also make use of the [`MCP2221Driver.SetGPIOOutputValuesCommand`](@ref) to avoid having to re-send the configuration of the other pins. It is then a simple matter of looping through the values. If you have LEDs connected to GP pins 2 and 3 (don't forget to put resistors!), the following code will make them blink alternatively for one minute.

```julia-repl
julia> for i in 1:60
           command = MCP2221Driver.SetGPIOOutputValuesCommand(gp2outputvalue=isodd(i), gp3outputvalue=iseven(i))
           MCP2221Driver.query(device, command)
           sleep(1)
       end

```

## Analog IO

GP pins 2 and 3 are also connected to the Digital-to-Analog Converter (DAC) outputs. This means we can use them tom produce analog tensions. In this section, we will use the DAC to produce a sine wave on GP pin 2 (a "smooth blink"). 

!!! note "A single DAC per chip"
    The MCP2221A only possesses one DAC, but both GP2 and GP3 can use it. If you configure both pins to use the DAC, they will present the same output.

The first step is to configure GP2 to use the DAC. This is pretty similar to what we did in the previous section.

```julia-repl
julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GetSRAMSettingsResponse(MCP2221Driver.Success, 0x12, 0x04, false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput3MHz, MCP2221Driver.Reference2p048, MCP2221Driver.SourceReferenceVRM, 0x00, true, true, MCP2221Driver.Reference1p024, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32, "\0\0\0\0\0\0\0\0", MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation), MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation))

julia> command = MCP2221Driver.SetSRAMSettingsCommand(gpiosettings=(gpio0=response.gpio0status, gpio1=response.gpio1status, gpio2=MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), gpio3=response.gpio3status))
MCP2221Driver.SetSRAMSettingsCommand(nothing, nothing, nothing, nothing, nothing, nothing, false, (gpio0 = MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), gpio1 = MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), gpio2 = MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), gpio3 = MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation)))

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GenericResponse(MCP2221Driver.Success)

```

The DAC is accessed through `AlternateFunction1` for GP2. See [`MCP2221Driver.GPDesignation`](@ref). All DAC settings are set through [`MCP2221Driver.SetSRAMSettingsCommand`](@ref). First, I will set the DAC to use the internal reference at 4.096V (see also [Analog to Digital / Ditital to Analog conversion](@ref) for options).

```julia-repl

julia> command = MCP2221Driver.GetSRAMSettingsCommand()
MCP2221Driver.GetSRAMSettingsCommand()

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GetSRAMSettingsResponse(MCP2221Driver.Success, 0x12, 0x04, false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput3MHz, MCP2221Driver.Reference2p048, MCP2221Driver.SourceReferenceVRM, 0x00, true, true, MCP2221Driver.Reference1p024, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32, "\0\0\0\0\0\0\0\0", MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation))

julia> response.dacreferencevoltage
Reference2p048::ReferenceVoltageOption = 0x02

julia> response.dacreferenceoption
SourceReferenceVRM::SourceReferenceOption = 0

julia> command = MCP2221Driver.SetSRAMSettingsCommand(dacsettings=(referencevoltage=MCP2221Driver.Reference4p096, referenceoption=MCP2221Driver.SourceReferenceVRM))
MCP2221Driver.SetSRAMSettingsCommand(nothing, (referencevoltage = MCP2221Driver.Reference4p096, referenceoption = MCP2221Driver.SourceReferenceVRM), nothing, nothing, nothing, nothing, false, nothing)

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GenericResponse(MCP2221Driver.Success)

julia> response = MCP2221Driver.query(device, command)
MCP2221Driver.GetSRAMSettingsResponse(MCP2221Driver.Success, 0x12, 0x04, false, MCP2221Driver.Unsecured, MCP2221Driver.ClockOutputDuty50, MCP2221Driver.ClockOutput3MHz, MCP2221Driver.Reference4p096, MCP2221Driver.SourceReferenceVRM, 0x00, true, true, MCP2221Driver.Reference1p024, MCP2221Driver.SourceReferenceVDD, 0x04d8, 0x00dd, 0x80, 0x32, "\0\0\0\0\0\0\0\0", MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction0), MCP2221Driver.GPIOStatus(true, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.AlternateFunction1), MCP2221Driver.GPIOStatus(false, MCP2221Driver.GPIOOutput, MCP2221Driver.GPIOOperation))

julia> response.dacreferencevoltage
Reference4p096::ReferenceVoltageOption = 0x03

julia> response.dacreferenceoption
SourceReferenceVRM::SourceReferenceOption = 0x01

```

We can now use the 5-bits DAC to generate a smooth blinking of the LED I have attached to GP2.

```julia-repl
julia> ys = @. round(UInt8, 31*(sin(2π*2*(1:0.1:60))/2 + 1))
591-element Vector{UInt8}:
 0x1f
 0x2e
 0x28
 0x16
 0x10
 0x1f
 0x2e
 0x28
 0x16
 0x10
    ⋮
 0x2e
 0x28
 0x16
 0x10
 0x1f
 0x2e
 0x28
 0x16
 0x10
 0x1f

julia> for y in ys
           command = MCP2221Driver.SetSRAMSettingsCommand(dacoutputvalue=y)
           MCP2221Driver.query(device, command)
           sleep(0.1)
       end

```

## I²C Operations

The MCP2221A is equiped with an I²C module that we can use to talk to other devices. In this section, we will illustrate these capabilities by communication with a TMP117 digital thermometer available at address 0.



