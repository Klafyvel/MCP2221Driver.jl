"Length in bytes of HID communcations."
const HID_MESSAGE_LENGTH = 64
"MCP2221A default Vendor ID (VID), as per documentation."
const MCP2221A_DEFAULT_VID = 0x04D8
"MCP2221A default Product ID (PID), as per documentation."
const MCP2221A_DEFAULT_PID = 0x00DD

"""
All mid-level commands inherit from `AbstractCommand`. Commands should satisfy
the [mid-level command interface](@ref midlevel_command_interface).
"""
abstract type AbstractCommand end
"""
All mid-level responses inherit from `AbstractResponse`. Responses should be able 
to build from an array of 64 `UInt8`.
"""
abstract type AbstractResponse end
"""
    commandcode(::T) where {T<:AbstractCommand} ::UInt8

Return the first byte of a command sequence, identifying the command.
"""
function commandcode end
"""
    subcommandcode(::T) where {T<:AbstractCommand} ::UInt8

Return the second byte of a command sequence, identifying the sub-command. Defaults to 0.
"""
subcommandcode(::AbstractCommand) = 0x00
"""
    responsetype(::Type{T}) where {T<:AbstractCommand}::Type{<:AbstractResponse}

Return the expected type of the command. It must me defined if [`expectsresponse`](@ref)
returns true for type `T`.
"""
function responsetype end
"""
    expectsresponse(::Type{T}) where {T<:AbstractCommand}::Bool

If `true`, read a response of type `responsetype(T)` from the device. Defaults to `true`.
"""
expectsresponse(::Type) = true

"""
    initarray!(command, v)

Initialize the array `v` given a `command`. The command does not have to handle the two first bytes. It assumes `v` elements are all zero.
"""
function initarray!(::AbstractCommand, v) end

"""
    asarray(command)

Build a $(HID_MESSAGE_LENGTH)-long `Vector{UInt8}` from the given `command`.
"""
@static if Sys.iswindows()
    # HIDApi behaves weirdly on windows. I expect bugs for long comands...
    function asarray(command)
        v = zeros(UInt8, HID_MESSAGE_LENGTH+1)
        v[2] = commandcode(command)
        v[3] = subcommandcode(command)
	initarray!(command, @view v[2:end])
	return v[1:end-1]
    end
else
    function asarray(command)
        v = zeros(UInt8, HID_MESSAGE_LENGTH)
        v[1] = commandcode(command)
        v[2] = subcommandcode(command)
        initarray!(command, v)
        return v
    end
end

"""
    query(dev, command)
Blocking call to the device to send the command and receive the response if one 
is expected.
"""
function query(dev, command::T) where {T <: AbstractCommand}
    hidcommand = asarray(command)
    write(dev, hidcommand)
    if expectsresponse(T)
        R = responsetype(T)
        return R(read(dev, HID_MESSAGE_LENGTH))
    else
        return nothing
    end
end


"""
Internal type used to make `DocStringExtensions.jl` document the link between
commands and reponses. Use with the `COMMANDSUMMARY` abbreviation.
"""
struct CommandSummary <: DocStringExtensions.Abbreviation end
const COMMANDSUMMARY = CommandSummary()
function DocStringExtensions.format(::CommandSummary, buf, doc)
    local binding = doc.data[:binding]
    local cmdtype = Docs.resolve(binding)
    if expectsresponse(cmdtype)
        resptype = responsetype(cmdtype)
        print(buf, "`$cmdtype` expects a [`$resptype`](@ref) response.")
    else
        print(buf, "`$cmdtype` does not expects a response.")
    end
    return nothing
end

"""
Status flag for a response.
- `Success`: command succeded,
- `I2CBusy`: 
- `CommandNotSupported`: Command not supported,
- `COmmandNotAllowed`: Command not allowed.
"""
@enum ResponseStatus::UInt8 Success = 0x00 I2CBusy = 0x01 CommandNotSupported = 0x02 CommandNotAllowed = 0x03 I2CError = 0x41
"""
A generic response where only the response status is interesting.

# Fields
$(TYPEDFIELDS)
"""
struct GenericResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
end
GenericResponse(v::Vector{UInt8}) = GenericResponse(ResponseStatus(v[2]))

"""
Poll the status of the device, and establish certain I²C bus parameters/conditions.

$(COMMANDSUMMARY)

# Fields
$(TYPEDFIELDS)
"""
struct StatusSetParametersCommand <: AbstractCommand
    "Cancel current I²C/SMBus transfer"
    cancelcurrent::Bool
    "Set I²C/SMBus communication speed. If set to 0 don't act. Otherwise the new clock speed is 12 MHz/divider"
    divider::Int8
end
commandcode(::StatusSetParametersCommand) = 0x10
function initarray!(c::StatusSetParametersCommand, a)
    if c.cancelcurrent
        a[3] = 0x10
    end
    if c.divider != 0x00
        a[4] = 0x20
        a[5] = c.divider
    end
    return
end

"""
Cancellation status after a [`StatusSetParametersCommand`](@ref):
- `NoSpecialOperation`  cancel current I²C/SMBus transfer,
- `MarkedForCancellation` current transferm marked for cancellation, bus release will need some time,
- `AlreadyIdle` the I²C engine was already in Idle mode.
"""
@enum CancellationStatus::UInt8 NoSpecialOperation = 0x00 MarkedForCancellation = 0x10 AlreadyIdle = 0x11
"""
Communication speed status after a [`StatusSetParametersCommand`](@ref):
- `NoSetSpeed` no new speed was issued,
- `NewSpeedConsidered` new speed is now considered,
- `SpeedNotSet` communication speed was not set.
"""
@enum CommunicationSpeedStatus::UInt8 NoSetSpeed = 0x00 NewSpeedConsidered = 0x20 SpeedNotSet = 0x21
"""
Response for a [`StatusSetParametersCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct StatusSetParametersResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    "Status of the cancellation request."
    cancellationstatus::CancellationStatus
    "Status of the new speed request."
    speedstatus::CommunicationSpeedStatus
    "Divider value for the speed."
    divider::UInt8
    "Length of the requested I²C transfer."
    requestedtransferlength::UInt16
    "Length of the already transfered I²C message."
    alreadytransferedlength::UInt16
    "Internal I²C data buffer counter."
    i2cbuffercounter::UInt8
    "Current communication speed divider value."
    currentcommunicationspeeddividervalue::UInt8
    "Current I²C timeout value."
    currenti2ctimeoutvalue::UInt8
    "Current I²C address."
    currenti2caddress::UInt16
    "If `ACK` was received from client."
    ackreceived::Bool
    "Current SCL line value."
    sclvalue::UInt8
    "Current SDA line value."
    sdavalue::UInt8
    "Interrupt edge detector state."
    interuptedgestate::Bool
    "I²C read pending value."
    i2creadpendingvalue::UInt8
    "MCP2221 hardware version."
    hardwareversion::VersionNumber
    "MCP2221 firmware version."
    firmwareversion::VersionNumber
    "Channel 0 ADC value."
    adcdatach0::UInt16
    "Channel 1 ADC value."
    adcdatach1::UInt16
    "Channel 2 ADC value."
    adcdatach2::UInt16
end
responsetype(::Type{StatusSetParametersCommand}) = StatusSetParametersResponse
StatusSetParametersResponse(v::Vector{UInt8}) = StatusSetParametersResponse(
    ResponseStatus(v[2]),
    CancellationStatus(v[3]),
    CommunicationSpeedStatus(v[4]),
    v[5],
    (UInt16(v[11]) << 8) | v[10],
    (UInt16(v[13]) << 8) | v[12],
    v[14], v[15], v[16],
    (UInt16(v[18]) << 8) | v[17],
    (v[21] & 0x40) > 0,
    v[23], v[24], v[25], v[26],
    VersionNumber(v[47], v[48]),
    VersionNumber(v[49], v[50]),
    (UInt16(v[52]) << 8) | v[51],
    (UInt16(v[54]) << 8) | v[53],
    (UInt16(v[56]) << 8) | v[54],
)

"Main type for reading the flash memory."
abstract type ReadFlashDataCommand <: AbstractCommand end
"""
Read chip settings from flash memory.

$(COMMANDSUMMARY) See also [`WriteFlashDataChipSettingsCommand`](@ref).
"""
struct ReadFlashDataChipSettingsCommand <: ReadFlashDataCommand end
"""
Read GP settings from flash memory.

$(COMMANDSUMMARY)
"""
struct ReadFlashDataGPSettingsCommand <: ReadFlashDataCommand end
"""
Read USB manufacturer string descriptor used during USB enumeration from flash memory.

$(COMMANDSUMMARY)
"""
struct ReadFlashDataUSBManufacturerDescriptorStringCommand <: ReadFlashDataCommand end
"""
Read USB product string descriptor used during USB enumeration from flash memory.

$(COMMANDSUMMARY)
"""
struct ReadFlashDataUSBProductDescriptorStringCommand <: ReadFlashDataCommand end
"""
Read USB serial number used during USB enumeration from flash memory.

$(COMMANDSUMMARY)
"""
struct ReadFlashDataUSBSerialNumberDescriptorStringCommand <: ReadFlashDataCommand end
"""
Read chip factory serial number from flash memory. Cannot be changed.

$(COMMANDSUMMARY)
"""
struct ReadFlashDataChipFactorySerialNumberCommand <: ReadFlashDataCommand end
commandcode(::ReadFlashDataCommand) = 0xb0
subcommandcode(::ReadFlashDataChipSettingsCommand) = 0x00
subcommandcode(::ReadFlashDataGPSettingsCommand) = 0x01
subcommandcode(::ReadFlashDataUSBManufacturerDescriptorStringCommand) = 0x02
subcommandcode(::ReadFlashDataUSBProductDescriptorStringCommand) = 0x03
subcommandcode(::ReadFlashDataUSBSerialNumberDescriptorStringCommand) = 0x04
subcommandcode(::ReadFlashDataChipFactorySerialNumberCommand) = 0x05

"""
Chip security configuration option:
- `PermanentlyLocked`
- `PasswordProtected`
- `Unsecured`
"""
@enum ChipConfigurationSecurityOption::UInt8 PermanentlyLocked = 0b10 PasswordProtected = 0b01 Unsecured = 0b00
"""
Reference voltage configuration for DAC and ADC.
- `Reference4p096`: reference is 4.096V (only if VDD is above this voltage)
- `Reference2p048`: reference is 2.048V 
- `Reference1p024`: reference is 1.024V
"""
@enum ReferenceVoltageOption::UInt8 Reference4p096 = 0b11 Reference2p048 = 0b10 Reference1p024 = 0b01 ReferenceVoltageOff = 0b00
"""
Reference voltage for DAC.
- `SourceReferenceVRM`: reference voltage is VRM
- `SourceReferenceVDD`: reference voltage is VDD
"""
@enum SourceReferenceOption::UInt8 SourceReferenceVDD = 0x00 SourceReferenceVRM = 0x01
"""
Clock output duty cycle for GP1.
"""
@enum ClockOutputDutyCycle::UInt8 ClockOutputDuty0 = 0b00 ClockOutputDuty25 = 0b01 ClockOutputDuty50 = 0b10 ClockOutputDuty75 = 0b11
"""
Clock output frequency for GP1.
"""
@enum ClockOutputFrequency::UInt8 ClockOutputReserved = 0x00 ClockOutput24MHz = 0x01 ClockOutput12MHz = 0x02 ClockOutput6MHz = 0x03 ClockOutput3MHz = 0x04 ClockOutput1p5MHz = 0x05 ClockOutput750kHz = 0x06 ClockOutput375kHz = 0x07
"""
Response for a [`ReadFlashDataChipSettingsCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct ReadFlashDataChipSettingsResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    "If true, the USB serial number will be used during the USB enumeration of the CDC interface."
    cdcserialnumberenumerationenable::Bool
    "Chip configuration security option."
    chipconfigurationsecurityoption::ChipConfigurationSecurityOption
    "If the GP pin is enabled for clock output operations, this is the duty cycle of the output."
    clockoutputduty::ClockOutputDutyCycle
    "If the GP pin is enabled for clock output operations, the divider value will be used on the 48MHz US internal clock and the divider output will be sent to this pin."
    clockoutputdividervalue::ClockOutputFrequency
    "DAC reference voltage option."
    dacreferencevoltage::ReferenceVoltageOption
    "DAC reference option."
    dacreferenceoption::SourceReferenceOption
    "Power-up DAC value."
    powerupdacvalue::UInt8
    "If `true`, the interrupt detection flag will be set when a negative edge occurs."
    interruptdetectionnegativeedge::Bool
    "If `true`, the interrupt detection flag will be set when a positive edge occurs."
    interruptdetectionpositiveedge::Bool
    "ADC reference voltage."
    adcreferencevoltage::ReferenceVoltageOption
    "ADC reference option."
    adcreferenceoption::SourceReferenceOption
    "USB VID value."
    vid::UInt16
    "USB PID value."
    pid::UInt16
    "USB power attribute as per USB 2.0 specification."
    usbpowerattributes::UInt8
    "USB requested number of mA(s) as per USB 2.0 specification."
    usbrequestednumberofma::UInt8
end
responsetype(::Type{ReadFlashDataChipSettingsCommand}) = ReadFlashDataChipSettingsResponse
ReadFlashDataChipSettingsResponse(v::Vector{UInt8}) = ReadFlashDataChipSettingsResponse(
    ResponseStatus(v[2]),
    Bool((v[5] & 0x80) >> 0x07),
    ChipConfigurationSecurityOption(v[5] & 0b11),
    ClockOutputDutyCycle((v[6] & 0x18) >> 0x03),
    ClockOutputFrequency(v[6] & 0x07),
    ReferenceVoltageOption(v[7] >> 0x06),
    if v[7] & 0x20 > 0
        SourceReferenceVRM
    else
        SourceReferenceVDD
    end,
    v[7] & 0x1f,
    (v[8] & 0x40) > 0,
    (v[8] & 0x20) > 0,
    ReferenceVoltageOption(v[8] & 0x18 >> 0x03),
    if v[8] & 0x04 > 0
        SourceReferenceVDD
    else
        SourceReferenceVRM
    end,
    (UInt16(v[10]) << 8) | v[9],
    (UInt16(v[12]) << 8) | v[11],
    v[13], v[14]
)

"""
Enum to set the dedicated function of a GP pin.
- `GPIOOperation`
- `DedicatedFunctionOperation`
- `AlternateFunction0`
- `AlternateFunction1`
- `AlternateFunction2`

!!! warning "Not all members available!"
    Not all members of the enum are available to all four GP pins. Refer to the following table for a list of available modes:

    | GP pin | `GPIOOperation` | `DedicatedFunctionOperation` | `AlternateFunction0` | `AlternateFunction1` | `AlternateFunction2` |
    | ------ | --------------- | ---------------------------- | -------------------- | -------------------- | -------------------- |
    | GP0    | Available       | SSPND                        | LED_URx              | Not Available        | Not Available        |
    | GP1    | Available       | clock output                 | ADC1                 | LED_UTx              | Interrupt detection  |
    | GP2    | Available       | USBCFG                       | ADC2                 | DAC1                 | Not Available        |
    | GP3    | Available       | LED_I2C                      | ADC3                 | DAC2                 | Not Available        |
"""
@enum GPDesignation::UInt8 GPIOOperation = 0x00 DedicatedFunctionOperation = 0x01 AlternateFunction0 = 0x02 AlternateFunction1 = 0x03 AlternateFunction2 = 0x04

"""
Enum to set the direction of a GP pin.
- `GPIOInput`
- `GPIOOutput`
"""
@enum GPDirection::Bool GPIOInput = true GPIOOutput = false

"""
Store the status of a GPIO.
    
# Fields
$(TYPEDFIELDS)
"""
struct GPIOStatus
    "Logical value present at the output."
    outputvalue::Bool
    "GPIO direction."
    direction::GPDirection
    "GPIO designation. See [`GPDesignation`](@ref) for a list of available designation for each pin."
    designation::GPDesignation
end
Base.convert(::Type{UInt8}, status::GPIOStatus) = UInt8((status.outputvalue << 4) | (UInt8(status.direction) << 3) | UInt8(status.designation))
Base.convert(::Type{GPIOStatus}, v::UInt8) = GPIOStatus(
    (v & 0x10) > 0,
    GPDirection((v & 0x08) > 9),
    GPDesignation(v & 0x07),
)

"""
Response for a [`ReadFlashDataGPSettingsCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct ReadFlashDataGPSettingsResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    "GPIO0 status at power-up."
    gpio0powerupstatus::GPIOStatus
    "GPIO1 status at power-up."
    gpio1powerupstatus::GPIOStatus
    "GPIO2 status at power-up."
    gpio2powerupstatus::GPIOStatus
    "GPIO3 status at power-up."
    gpio3powerupstatus::GPIOStatus
end
ReadFlashDataGPSettingsResponse(v::Vector{UInt8}) = ReadFlashDataGPSettingsResponse(
    ResponseStatus(v[2]),
    v[5], v[6], v[7], v[8]
)
responsetype(::Type{ReadFlashDataGPSettingsCommand}) = ReadFlashDataGPSettingsResponse

"""
A generic response for commands that respond with a string.

# Fields
$(TYPEDFIELDS)
"""
struct StringResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    "Response."
    string::String
end
function StringResponse(v::Vector{UInt8})
    l = (v[3] - 2)
    s = map(zip(v[5:2:(5 + l)], v[6:2:(6 + l)])) do (l, h)
        Char(UInt16(h) << 8 | l)
    end |> String
    return StringResponse(ResponseStatus(v[2]), s)
end
responsetype(::Type{ReadFlashDataUSBManufacturerDescriptorStringCommand}) = StringResponse
responsetype(::Type{ReadFlashDataUSBProductDescriptorStringCommand}) = StringResponse
responsetype(::Type{ReadFlashDataUSBSerialNumberDescriptorStringCommand}) = StringResponse

"""
Response for a [`ReadFlashDataChipFactorySerialNumberCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct ReadFlashDataChipFactorySerialNumberResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    "Chip factory serial number, typically 8 bytes long."
    number::Vector{UInt8}
    function ReadFlashDataChipFactorySerialNumberResponse(v::Vector{UInt8})
        l = v[3]
        return new(ResponseStatus(v[2]), v[5:(5 + l)])
    end
end
responsetype(::Type{ReadFlashDataChipFactorySerialNumberCommand}) = ReadFlashDataChipFactorySerialNumberResponse

"""
Abstract supertype for all flash writing operations. Used internally because
the MCP2221 actually have only one command divided in sub-commands for this.
"""
abstract type WriteFlashDataCommand <: AbstractCommand end
"""
Write chip settings into Flash memory.

$(COMMANDSUMMARY) See also [`ReadFlashDataChipSettingsCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct WriteFlashDataChipSettingsCommand <: WriteFlashDataCommand
    "If true, the USB serial number will be used during the USB enumeration of the CDC interface."
    cdcserialnumberenumerationenable::Bool
    "Chip configuration security option."
    chipconfigurationsecurityoption::ChipConfigurationSecurityOption
    "If the GP pin is enabled for clock output operations, this is the duty cycle of the output."
    clockoutputduty::ClockOutputDutyCycle
    "If the GP pin is enabled for clock output operations, the divider value will be used on the 48MHz US internal clock and the divider output will be sent to this pin."
    clockoutputdividervalue::ClockOutputFrequency
    "DAC reference voltage option."
    dacreferencevoltage::ReferenceVoltageOption
    "DAC reference option."
    dacreferenceoption::SourceReferenceOption
    "Power-up DAC value."
    powerupdacvalue::UInt8
    "If `true`, the interrupt detection flag will be set when a negative edge occurs."
    interruptdetectionnegativeedge::Bool
    "If `true`, the interrupt detection flag will be set when a positive edge occurs."
    interruptdetectionpositiveedge::Bool
    "ADC reference voltage."
    adcreferencevoltage::ReferenceVoltageOption
    "ADC reference option."
    adcreferenceoption::SourceReferenceOption
    "USB VID value."
    vid::UInt16
    "USB PID value."
    pid::UInt16
    "USB power attribute as per USB 2.0 specification."
    usbpowerattributes::UInt8
    "USB requested number of mA(s) as per USB 2.0 specification."
    usbrequestednumberofma::UInt8
    "8-byte password (for Flash modifications protection)."
    password::String
    function WriteFlashDataChipSettingsCommand(args::Vararg{Any, 16})
        password = args[16]::String
        if ncodeunits(password) > 8
            throw(OverflowError("Your password can be at most 8 code units."))
        end
        return new(args...)
    end
end
function initarray!(c::WriteFlashDataChipSettingsCommand, v)
    if c.cdcserialnumberenumerationenable
        v[3] = v[3] | 0x80
    end
    if c.chipconfigurationsecurityoption == PermanentlyLocked
        v[3] = v[3] | 0x03
    elseif c.chipconfigurationsecurityoption == PasswordProtected
        v[3] = v[3] | 0x01
    else
        v[3] = v[3] | 0x00
    end
    v[4] = (UInt8(c.clockoutputduty) << 0x03) | UInt8(c.clockoutputdividervalue)
    v[5] = UInt8(c.dacreferencevoltage) << 6
    if c.dacreferenceoption == SourceReferenceVDD
        v[5] = v[5] | 0x20
    end
    if c.interruptdetectionnegativeedge
        v[6] = v[6] | 0x40
    end
    if c.interruptdetectionpositiveedge
        v[6] = v[6] | 0x20
    end
    v[6] = v[6] | (UInt8(c.adcreferencevoltage) << 3)
    if c.dacreferenceoption == SourceReferenceVDD
        v[6] = v[6] | 0x04
    end
    v[7] = UInt8(c.vid & 0x00ff)
    v[8] = UInt8((c.vid & 0xff00) >> 0x08)
    v[9] = UInt8(c.pid & 0x00ff)
    v[10] = UInt8((c.pid & 0xff00) >> 0x08)
    v[11] = c.usbpowerattributes
    v[12] = c.usbrequestednumberofma
    for (i, b) in enumerate(ByteStringIterator{1}(c.password, false))
        v[12 + i] = b
    end
    return
end
"""
Write GP settings into Flash memory.

$(COMMANDSUMMARY)  [`ReadFlashDataGPSettingsCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct WriteFlashDataGPSettingsCommand <: WriteFlashDataCommand
    "GPIO0 status at power-up."
    gpio0powerupstatus::GPIOStatus
    "GPIO1 status at power-up."
    gpio1powerupstatus::GPIOStatus
    "GPIO2 status at power-up."
    gpio2powerupstatus::GPIOStatus
    "GPIO3 status at power-up."
    gpio3powerupstatus::GPIOStatus
end
function initarray!(c::WriteFlashDataGPSettingsCommand, v)
    v[3] = c.gpio0powerupstatus
    v[4] = c.gpio1powerupstatus
    v[5] = c.gpio2powerupstatus
    v[6] = c.gpio3powerupstatus
    return
end
"""
Abstract super-type for all commands writing a string to flash memory. The 
subtypes are expected to expose a `string` attribute.
"""
abstract type WriteFlashStringCommand <: WriteFlashDataCommand end
"""
Write USB manufacturer descriptor string into Flash memory.

$(COMMANDSUMMARY) See also [`ReadFlashDataUSBManufacturerDescriptorStringCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct WriteFlashDataUSBManufacturerDescriptorStringCommand <: WriteFlashStringCommand
    string::String
end
"""
Write USB product descriptor string into Flash memory.

$(COMMANDSUMMARY) See also [`ReadFlashDataUSBProductDescriptorStringCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct WriteFlashDataUSBProductDescriptorStringCommand <: WriteFlashStringCommand
    string::String
end
"""
Write USB serial number descriptor string into Flash memory.

$(COMMANDSUMMARY) See also [`ReadFlashDataUSBSerialNumberDescriptorStringCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct WriteFlashDataUSBSerialNumberDescriptorStringCommand <: WriteFlashStringCommand
    string::String
end
function initarray!(command::WriteFlashStringCommand, v)
    l = length(command.string)
    v[3] = 2 + 2 * l
    v[4] = 0x03 # Required by the datasheet.
    for (i, b) in enumerate(ByteStringIterator{2}(command.string, true))
        v[4 + i] = b
    end
    return
end
commandcode(::WriteFlashDataCommand) = 0xb1
subcommandcode(::WriteFlashDataChipSettingsCommand) = 0x00
subcommandcode(::WriteFlashDataGPSettingsCommand) = 0x01
subcommandcode(::WriteFlashDataUSBManufacturerDescriptorStringCommand) = 0x02
subcommandcode(::WriteFlashDataUSBProductDescriptorStringCommand) = 0x03
subcommandcode(::WriteFlashDataUSBSerialNumberDescriptorStringCommand) = 0x04

responsetype(::Type{WriteFlashDataChipSettingsCommand}) = GenericResponse
responsetype(::Type{WriteFlashDataGPSettingsCommand}) = GenericResponse
responsetype(::Type{WriteFlashDataUSBManufacturerDescriptorStringCommand}) = GenericResponse
responsetype(::Type{WriteFlashDataUSBProductDescriptorStringCommand}) = GenericResponse
responsetype(::Type{WriteFlashDataUSBSerialNumberDescriptorStringCommand}) = GenericResponse

"""
Send user-supplied password that will be compared to the one stored in the device's 
Flash when Flash updates are required and the Flash data are password-protected.

The password must be at most 8 bytes long. If your string contains characters more
than one byte long, their LSB will be written first.

$(COMMANDSUMMARY)

# Fields
$(TYPEDFIELDS)
"""
struct SendFlashAccessPasswordCommand <: AbstractCommand
    "8-bytes of password."
    password::AbstractString
    function SendFlashAccessPassword(password)
        if ncodeunits(password) > 8
            throw(OverflowError("Your password can be at most 8 code units."))
        end
        return new(password)
    end
end
function initarray!(command::SendFlashAccessPasswordCommand, v)
    for (i, b) in enumerate(ByteStringIterator{1}(command.password, false))
        v[2 + i] = b
    end
    return
end
commandcode(::SendFlashAccessPasswordCommand) = 0xb2
responsetype(::Type{SendFlashAccessPasswordCommand}) = GenericResponse

"""
Facility container for storing I²C addresses. Users generally should not care about
this.

# Fields
$(TYPEDFIELDS)
"""
struct I2CAddress
    address::UInt8
    function I2CAddress(address)
        if !(0 ≤ address ≤ 127)
            throw(DomainError(address, "I²C addresses can only range in [0,127]."))
        end
        return new(address)
    end
end
"""
Format an address for a write command according to MCP2221's specification. 
"""
writeaddress(a::I2CAddress) = a.address << 1
"""
Format an address for a read command according to MCP2221's specification. 
"""
readaddress(a::I2CAddress) = (a.address << 1) + 0x01
Base.convert(::Type{I2CAddress}, n::Real) = I2CAddress(n)

"""
I²C Frame mode. Writing and reading on the I²C bus is affected by this enumeration.
- `I2CSingle`
- `I2CRepeatedStart`
- `I2CNoStop`
"""
@enum I2CFrameMode I2CSingle I2CRepeatedStart I2CNoStop

"""
Write data on the I²C bus. Depending on the chosen [`I2CFrameMode`](@ref), the 
behavior will vary. The command has the following effects:
- Send the "Start" (`I2CSingle`, `I2CNoStop`) or "RepeatedStart" (`I2CRepeatedStart`) condition.
- Send the I²C client address and wait for the client to send an Acknowledge bit.
- The user data follow next. The I²C engine waits for the Acknowledge bit from the client.
- If the requested length is more than 60 bytes, subsequent user bytes will be sent on the bus.
- When the user data length reaches the requested length, the I²C engine will send the "Stop" condition on the bus, except when the mode is `I2CNoStop`.

Note that you can send data longer than 60 bytes by repeating the command, but this
layer will not take care of that for you and will error if your `data` is longer
than 60 bytes.

$(COMMANDSUMMARY)

# Fields
$(TYPEDFIELDS)
"""
struct I2CWriteDataCommand <: AbstractCommand
    address::I2CAddress
    writemode::I2CFrameMode
    data::Vector{UInt8}
    function I2CWriteDataCommand(address, writemode, data)
        if length(data) > 60
            throw(DomainError(length(data), "A write command can contain at most 60 bytes."))
        end
        return new(address, writemode, data)
    end
end

commandcode(c::I2CWriteDataCommand) =
if c.writemode == I2CSingle
    0x90
elseif c.writemode == I2CRepeatedStart
    0x92
else
    0x94
end

responsetype(::Type{I2CWriteDataCommand}) = GenericResponse
function initarray!(command::I2CWriteDataCommand, v)
    l = length(command.data)
    v[2] = UInt8(l & 0xff)
    v[3] = UInt8((l >> 0x08) & 0xff)
    v[4] = writeaddress(command.address)
    v[5:(5 + l - 1)] = command.data
    return
end

"""
Read data from the I²C bus. Depending on the chosen [`I2CFrameMode`](@ref), the 
behavior will vary. Note that the `I2CNoStop` mode is not supported. The command 
has the following effects:
- Send the "Start" (`I2CSingle`) or "RepeatedStart" (`I2CRepeatedStart`) condition.
- Send the I²C client address and wait for the client to send an Acknowledge bit.
- The user data follow next. The I²C engine sends the Acknowledge bit to the client.
- If the requested length is more than 60 bytes, subsequent user bytes will be read from the bus.
- When the user data length reaches the requested length, the I²C engine will send the "Stop" condition on the bus.

$(COMMANDSUMMARY)

# Fields
$(TYPEDFIELDS)
"""
struct I2CReadDataCommand <: AbstractCommand
    address::I2CAddress
    readmode::I2CFrameMode
    length::UInt16
    function I2CReadDataCommand(address, readmode, length)
        if readmode == I2CNoStop
            throw(DomainError(readmode, "The only supported modes are `I2CSingle` and `I2CRepeatedStart`."))
        end
        return new(address, readmode, length)
    end
end
responsetype(::Type{I2CReadDataCommand}) = GenericResponse
commandcode(c::I2CReadDataCommand) =
if c.readmode == I2CSingle
    0x91
else
    0x93
end
function initarray!(command::I2CReadDataCommand, v)
    l = command.length
    v[2] = UInt8(l & 0xff)
    v[3] = UInt8((l >> 0x08) & 0xff)
    v[4] = readaddress(command.address)
    return
end

"""
This command is used to read back the data from the I2C client device.

$(COMMANDSUMMARY)
"""
struct GetI2CDataCommand <: AbstractCommand end
commandcode(::GetI2CDataCommand) = 0x40

"""
Response to a [`GetI2CDataCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct GetI2CDataResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    data::Vector{UInt8}
end
responsetype(::Type{GetI2CDataCommand}) = GetI2CDataResponse
function GetI2CDataResponse(v::Vector{UInt8})
    l = v[4]
    if 0 < l ≤ 60
        return GetI2CDataResponse(ResponseStatus(v[2]), v[5:(5 + l - 1)])
    else
        return GetI2CDataResponse(ResponseStatus(v[2]), [])
    end
end

"""
This command is used to change the GPIO output value for those GP pins assigned 
for GPIO operation (GPIO outputs).

$(COMMANDSUMMARY)

# Fields
$(TYPEDFIELDS)
"""
struct SetGPIOOutputValuesCommand <: AbstractCommand
    "GP0 output value, set to `nothing` to leave unchanged."
    gp0outputvalue::Union{Nothing, Bool}
    """GP0 pin direction, set to `nothing` to leave unchanged, `false` for 
    output, `true` for input."""
    gp0pindirection::Union{Nothing, Bool}
    "GP1 output value, set to `nothing` to leave unchanged."
    gp1outputvalue::Union{Nothing, Bool}
    """GP1 pin direction, set to `nothing` to leave unchanged, `false` for 
    output, `true` for input."""
    gp1pindirection::Union{Nothing, Bool}
    "GP2 output value, set to `nothing` to leave unchanged."
    gp2outputvalue::Union{Nothing, Bool}
    """GP2 pin direction, set to `nothing` to leave unchanged, `false` for 
    output, `true` for input."""
    gp2pindirection::Union{Nothing, Bool}
    "GP3 output value, set to `nothing` to leave unchanged."
    gp3outputvalue::Union{Nothing, Bool}
    """GP3 pin direction, set to `nothing` to leave unchanged, `false` for 
    output, `true` for input."""
    gp3pindirection::Union{Nothing, Bool}
end
SetGPIOOutputValuesCommand(;
    gp0outputvalue = nothing, gp0pindirection = nothing,
    gp1outputvalue = nothing, gp1pindirection = nothing,
    gp2outputvalue = nothing, gp2pindirection = nothing,
    gp3outputvalue = nothing, gp3pindirection = nothing
) = SetGPIOOutputValuesCommand(
    gp0outputvalue, gp0pindirection,
    gp1outputvalue, gp1pindirection,
    gp2outputvalue, gp2pindirection,
    gp3outputvalue, gp3pindirection
)
commandcode(::SetGPIOOutputValuesCommand) = 0x50
function initarray!(command::SetGPIOOutputValuesCommand, v)
    fieldnames = [
        (:gp0outputvalue, :gp0pindirection),
        (:gp1outputvalue, :gp1pindirection),
        (:gp2outputvalue, :gp2pindirection),
        (:gp3outputvalue, :gp3pindirection),
    ]
    for (i, (outputname, directionname)) in enumerate(fieldnames)
        output = getfield(command, outputname)
        direction = getfield(command, directionname)
        if !isnothing(output)
            v[4i - 1] = 0x01
            v[4i] = output
        end
        if !isnothing(direction)
            v[4i + 1] = 0x01
            v[4i + 2] = direction
        end
    end
    return
end
responsetype(::Type{SetGPIOOutputValuesCommand}) = GenericResponse

"""
This command is used to retrieve the GPIO direction and pin value for those GP 
pins assigned for GPIO operation (GPIO inputs or outputs).

$(COMMANDSUMMARY)
"""
struct GetGPIOValuesCommand <: AbstractCommand end
commandcode(::GetGPIOValuesCommand) = 0x51
"""
Response to a [`GetGPIOValuesCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct GetGPIOValuesResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    "GP0 logic pin value, or `nothing` if not set for GPIO operations."
    gp0pinvalue::Union{Nothing, Bool}
    "GP0 pin designation (`false` for output `true` for input), or nothing if not set for GPIO operations."
    gp0directionvalue::Union{Nothing, Bool}
    "GP1 logic pin value, or `nothing` if not set for GPIO operations."
    gp1pinvalue::Union{Nothing, Bool}
    "GP1 pin designation (`false` for output `true` for input), or nothing if not set for GPIO operations."
    gp1directionvalue::Union{Nothing, Bool}
    "GP2 logic pin value, or `nothing` if not set for GPIO operations."
    gp2pinvalue::Union{Nothing, Bool}
    "GP2 pin designation (`false` for output `true` for input), or nothing if not set for GPIO operations."
    gp2directionvalue::Union{Nothing, Bool}
    "GP3 logic pin value, or `nothing` if not set for GPIO operations."
    gp3pinvalue::Union{Nothing, Bool}
    "GP3 pin designation (`false` for output `true` for input), or nothing if not set for GPIO operations."
    gp3directionvalue::Union{Nothing, Bool}
end
nothing_or_bool(v) =
if v > 0x01
    nothing
else
    Bool(v)
end
GetGPIOValuesResponse(v::Vector{UInt8}) = GetGPIOValuesResponse(
    ResponseStatus(v[2]),
    nothing_or_bool(v[3]),
    nothing_or_bool(v[4]),
    nothing_or_bool(v[5]),
    nothing_or_bool(v[6]),
    nothing_or_bool(v[7]),
    nothing_or_bool(v[8]),
    nothing_or_bool(v[9]),
    nothing_or_bool(v[10]),
)
responsetype(::Type{GetGPIOValuesCommand}) = GetGPIOValuesResponse

"""
This command is used to al,er various run-time Chip settings. The altered 
settings reside in SRAM me,ory and they will not affect the Chip’s 
power-up/Reset default settings. These altered settings will be active until 
the next chip power-up/Reset.

$(COMMANDSUMMARY)

# Fields
$(TYPEDFIELDS)
"""
struct SetSRAMSettingsCommand <: AbstractCommand
    """If the GP pin is enabled for clock output operations, these are the duty 
     cycle and the output frequency. 
    """
    clockoutputsettings::Union{Nothing, @NamedTuple{duty::ClockOutputDutyCycle, dividervalue::ClockOutputFrequency}}
    "DAC settings."
    dacsettings::Union{Nothing, @NamedTuple{referencevoltage::ReferenceVoltageOption, referenceoption::SourceReferenceOption}}
    "DAC output value, only the 5 LSB are taken into account."
    dacoutputvalue::Union{UInt8, Nothing}
    "ADC settings."
    adcsettings::Union{Nothing, @NamedTuple{referencevoltage::ReferenceVoltageOption, referenceoption::SourceReferenceOption}}
    "If set to a boolean value, control wether interrupt detection will trigger on positive edges."
    interruptdetectionpositiveedge::Union{Bool, Nothing}
    "If set to a boolean value, control wether interrupt detection will trigger on negative edges."
    interruptdetectionnegativeedge::Union{Bool, Nothing}
    "If set to `true`, clear the interrupt flag. Default is `false`."
    clearinterrupt::Bool
    "If set, change GPIO settings. For more fine-grained control, see [`SetGPIOOutputValuesCommand`](@ref)."
    gpiosettings::Union{Nothing, @NamedTuple{gpio0::GPIOStatus, gpio1::GPIOStatus, gpio2::GPIOStatus, gpio3::GPIOStatus}}
end
SetSRAMSettingsCommand(;
    clockoutputsettings = nothing,
    dacsettings = nothing,
    dacoutputvalue = nothing,
    adcsettings = nothing,
    interruptdetectionpositiveedge = nothing,
    interruptdetectionnegativeedge = nothing,
    clearinterrupt = false,
    gpiosettings = nothing
) = SetSRAMSettingsCommand(
    clockoutputsettings, dacsettings, dacoutputvalue, adcsettings,
    interruptdetectionpositiveedge, interruptdetectionnegativeedge,
    clearinterrupt, gpiosettings
)
commandcode(::SetSRAMSettingsCommand) = 0x60
responsetype(::Type{SetSRAMSettingsCommand}) = GenericResponse
function initarray!(c::SetSRAMSettingsCommand, v)
    if !isnothing(c.clockoutputsettings)
        v[3] = 0x80 | (UInt8(c.clockoutputsettings.duty) << 0x03) | UInt8(c.clockoutputsettings.dividervalue)
    end
    if !isnothing(c.dacsettings)
        v[4] = 0x80 | (UInt8(c.dacsettings.referencevoltage) << 0x01) | UInt8(c.dacsettings.referenceoption)
    end
    if !isnothing(c.dacoutputvalue)
        v[5] = 0x80 | c.dacoutputvalue
    end
    if !isnothing(c.adcsettings)
        v[6] = 0x80 | (UInt8(c.adcsettings.referencevoltage) << 0x01) | UInt8(c.adcsettings.referenceoption)
    end
    if !isnothing(c.interruptdetectionpositiveedge) || !isnothing(c.interruptdetectionnegativeedge) || c.clearinterrupt
        v[7] = 0x80
        if !isnothing(c.interruptdetectionpositiveedge)
            v[7] = v[7] | 0x10 | (c.interruptdetectionpositiveedge << 0x03)
        end
        if !isnothing(c.interruptdetectionnegativeedge)
            v[7] = v[7] | 0x04 | (c.interruptdetectionnegativeedge << 0x01)
        end
        v[7] = v[7] | c.clearinterrupt
    end
    return if !isnothing(c.gpiosettings)
        v[8] = 0x80
        v[9] = c.gpiosettings.gpio0
        v[10] = c.gpiosettings.gpio1
        v[11] = c.gpiosettings.gpio2
        v[12] = c.gpiosettings.gpio3
    end
end

"""
This command is used to retrieve the run-time Chip and GP settings.

$(COMMANDSUMMARY)
"""
struct GetSRAMSettingsCommand <: AbstractCommand end
commandcode(::GetSRAMSettingsCommand) = 0x61
"""
Response to a [`GetSRAMSettingsCommand`](@ref).

# Fields
$(TYPEDFIELDS)
"""
struct GetSRAMSettingsResponse <: AbstractResponse
    "See [`ResponseStatus`](@ref)."
    status::ResponseStatus
    "Length in bytes of the SRAM Chip settings area."
    lengthchipsettings::UInt8
    "Length in bytes of the SRAM GP settings area."
    lengthgpsettings::UInt8
    "If true, the USB serial number will be used during the USB enumeration of the CDC interface."
    cdcserialnumberenumerationenable::Bool
    "Chip configuration security option."
    chipconfigurationsecurityoption::ChipConfigurationSecurityOption
    "If the GP pin is enabled for clock output operations, this is the duty cycle of the output."
    clockoutputduty::ClockOutputDutyCycle
    "If the GP pin is enabled for clock output operations, the divider value will be used on the 48MHz US internal clock and the divider output will be sent to this pin."
    clockoutputdividervalue::ClockOutputFrequency
    "DAC reference voltage option."
    dacreferencevoltage::ReferenceVoltageOption
    "DAC reference option."
    dacreferenceoption::SourceReferenceOption
    "Power-up DAC value."
    powerupdacvalue::UInt8
    "If `true`, the interrupt detection flag will be set when a negative edge occurs."
    interruptdetectionnegativeedge::Bool
    "If `true`, the interrupt detection flag will be set when a positive edge occurs."
    interruptdetectionpositiveedge::Bool
    "ADC reference voltage."
    adcreferencevoltage::ReferenceVoltageOption
    "ADC reference option."
    adcreferenceoption::SourceReferenceOption
    "USB VID value."
    vid::UInt16
    "USB PID value."
    pid::UInt16
    "USB power attribute as per USB 2.0 specification."
    usbpowerattributes::UInt8
    "USB requested number of mA(s) as per USB 2.0 specification."
    usbrequestednumberofma::UInt8
    "Current Supplied Password (8 bytes)."
    password::String
    "GPIO0 status."
    gpio0status::GPIOStatus
    "GPIO1 status."
    gpio1status::GPIOStatus
    "GPIO2 status."
    gpio2status::GPIOStatus
    "GPIO3 status."
    gpio3status::GPIOStatus
end
responsetype(::Type{GetSRAMSettingsCommand}) = GetSRAMSettingsResponse
GetSRAMSettingsResponse(v::Vector{UInt8}) = GetSRAMSettingsResponse(
    ResponseStatus(v[2]),
    v[3], v[4],
    Bool((v[5] & 0x80) >> 0x07),
    ChipConfigurationSecurityOption(v[5] & 0b11),
    ClockOutputDutyCycle((v[6] & 0x18) >> 0x03), ClockOutputFrequency(v[6] & 0x07),
    ReferenceVoltageOption(v[7] >> 0x06),
    if v[7] & 0x20 > 0
        SourceReferenceVRM
    else
        SourceReferenceVDD
    end,
    v[7] & 0x1f,
    (v[8] & 0x40) > 0, (v[8] & 0x20) > 0,
    ReferenceVoltageOption((v[8] & 0x18) >> 0x03),
    if v[8] & 0x04 > 0
        SourceReferenceVDD
    else
        SourceReferenceVRM
    end,
    (UInt16(v[10]) << 8) | v[9],
    (UInt16(v[12]) << 8) | v[11],
    v[13], v[14],
    String(v[15:22]),
    v[23], v[24], v[25], v[26]
)

"""
This command is used to force a Reset of the MCP2221A device. This command is 
useful when the Flash memory is updated with new data. The MCP2221A would need 
to be re-enumerated to see the new data.

$(COMMANDSUMMARY)

!!! note 
    This command is the only command that does not expect a response.
"""
struct ResetChipCommand <: AbstractCommand end
expectsresponse(::Type{ResetChipCommand}) = false
commandcode(::ResetChipCommand) = 0x70
function initarray!(::ResetChipCommand, v)
    v[2] = 0xAB
    v[3] = 0xCD
    v[4] = 0xEF
    return
end
