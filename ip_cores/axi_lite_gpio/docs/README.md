# AXI4-Lite GPIO Controller

## Overview

The AXI4-Lite GPIO Controller is a configurable general-purpose input/output (GPIO) peripheral that provides an AXI4-Lite slave interface for system integration. This IP core allows software control of GPIO pins with configurable width and direction.

## Features

- **Configurable Width Per Channel**: Support for 1 to 32-bit GPIO width per channel (each channel can have different width)
- **Multi-Channel Support**: Up to 2 independent GPIO channels with different configurations
- **Individual Pin Control**: Each GPIO pin can be independently configured as input or output
- **AXI4-Lite Interface**: Standard AXI4-Lite slave interface for easy system integration
- **Tristate Control**: Proper tristate control for bidirectional GPIO pins
- **Parameter Validation**: Compile-time parameter validation for robustness

## Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `GPIO_WIDTH_CH0` | int | 8 | 1-32 | Width of GPIO channel 0 in bits |
| `GPIO_WIDTH_CH1` | int | 8 | 1-32 | Width of GPIO channel 1 in bits |
| `NUM_CHANNELS` | int | 1 | 1-2 | Number of GPIO channels |
| `ADDR_WIDTH` | int | 4 | ≥4 | AXI4-Lite address width |

## Interface Signals

### Clock and Reset
- `aclk` - AXI4-Lite clock
- `aresetn` - AXI4-Lite active-low reset

### AXI4-Lite Slave Interface
Complete AXI4-Lite slave interface including:
- Write Address Channel: `s_axi_awaddr`, `s_axi_awprot`, `s_axi_awvalid`, `s_axi_awready`
- Write Data Channel: `s_axi_wdata`, `s_axi_wstrb`, `s_axi_wvalid`, `s_axi_wready`
- Write Response Channel: `s_axi_bresp`, `s_axi_bvalid`, `s_axi_bready`
- Read Address Channel: `s_axi_araddr`, `s_axi_arprot`, `s_axi_arvalid`, `s_axi_arready`
- Read Data Channel: `s_axi_rdata`, `s_axi_rresp`, `s_axi_rvalid`, `s_axi_rready`

### GPIO Interface
- **Channel 0**: `gpio_io_i[GPIO_WIDTH_CH0-1:0]`, `gpio_io_o[GPIO_WIDTH_CH0-1:0]`, `gpio_io_t[GPIO_WIDTH_CH0-1:0]`
- **Channel 1**: `gpio2_io_i[GPIO_WIDTH_CH1-1:0]`, `gpio2_io_o[GPIO_WIDTH_CH1-1:0]`, `gpio2_io_t[GPIO_WIDTH_CH1-1:0]` (only present if NUM_CHANNELS > 1)

Where:
- `gpio_io_i` / `gpio2_io_i` - GPIO input pins for each channel
- `gpio_io_o` / `gpio2_io_o` - GPIO output pins for each channel
- `gpio_io_t` / `gpio2_io_t` - GPIO tristate control (1=input, 0=output) for each channel

**Note**: Channel 1 signals are always present in the interface but are tied to safe values when NUM_CHANNELS = 1.

## Register Map

| Address | Register Name | Access | Description |
|---------|---------------|--------|-------------|
| 0x00 | CH0_DATA | R/W | Channel 0 Data Register |
| 0x04 | CH0_DIR | R/W | Channel 0 Direction Register |
| 0x08 | CH1_DATA | R/W | Channel 1 Data Register (if NUM_CHANNELS > 1) |
| 0x0C | CH1_DIR | R/W | Channel 1 Direction Register (if NUM_CHANNELS > 1) |

### Register Descriptions

#### CHx_DATA (Channel Data Register)
- **Read**: Returns current GPIO pin values
  - For output pins: returns the value written to the data register
  - For input pins: returns the actual pin state from `gpio_i`
- **Write**: Sets output values for pins configured as outputs
- **Reset Value**: 0x00000000

#### CHx_DIR (Channel Direction Register)  
- **Bit Value**: 1 = Output, 0 = Input
- **Read**: Returns current direction configuration
- **Write**: Configures pin directions
- **Reset Value**: 0x00000000 (all pins as inputs)

## Usage Example

### Verilog Instantiation

```verilog
axi_lite_gpio #(
    .GPIO_WIDTH_CH0(16),  // 16-bit GPIO Channel 0
    .GPIO_WIDTH_CH1(8),   // 8-bit GPIO Channel 1
    .NUM_CHANNELS(2),     // 2 channels
    .ADDR_WIDTH(4)        // 4-bit address
) gpio_inst (
    .aclk(axi_clk),
    .aresetn(axi_resetn),
    
    // AXI4-Lite interface
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    
    // GPIO interface - Channel 0 (16-bit)
    .gpio_io_i(gpio0_inputs),
    .gpio_io_o(gpio0_outputs),
    .gpio_io_t(gpio0_tristate),
    
    // GPIO interface - Channel 1 (8-bit)
    .gpio2_io_i(gpio1_inputs),
    .gpio2_io_o(gpio1_outputs),
    .gpio2_io_t(gpio1_tristate)
);
```

### Software Programming Example (C)

```c
// Base address of GPIO peripheral
#define GPIO_BASE_ADDR 0x40000000

// Register offsets
#define CH0_DATA_REG   (GPIO_BASE_ADDR + 0x00)
#define CH0_DIR_REG    (GPIO_BASE_ADDR + 0x04)
#define CH1_DATA_REG   (GPIO_BASE_ADDR + 0x08)
#define CH1_DIR_REG    (GPIO_BASE_ADDR + 0x0C)

// Configure Channel 0 pins [7:0] as outputs, [15:8] as inputs
*(volatile uint32_t*)CH0_DIR_REG = 0x00FF;

// Set Channel 0 output pins to 0xAA
*(volatile uint32_t*)CH0_DATA_REG = 0x00AA;

// Read Channel 0 data (will return outputs + inputs)
uint32_t ch0_value = *(volatile uint32_t*)CH0_DATA_REG;
```

## Implementation Details

### AXI4-Lite Protocol Compliance
- Supports 32-bit data width with byte enable strobes
- Implements proper AXI4-Lite handshaking protocols
- Provides OKAY responses for all valid transactions
- Address decoding based on bits [3:2] for 4-register map

### GPIO Control Logic
- Direction register controls pin functionality (1=output, 0=input)
- Output values driven from data register when pin is configured as output
- Input values read directly from `gpio_i` when pin is configured as input
- Tristate control automatically managed based on direction configuration

### Reset Behavior
- All registers reset to 0 (all pins as inputs, all outputs low)
- AXI4-Lite interface properly reset to idle state

## Resource Utilization

The resource utilization will vary based on parameters:
- **GPIO_WIDTH_CH0/CH1**: Directly affects register width and GPIO pin count for each channel
- **NUM_CHANNELS**: Determines number of active channels
- **ADDR_WIDTH**: Minimal impact on resources

Typical utilization for a 16-bit channel 0 + 8-bit channel 1 configuration:
- **Registers**: ~96 bits (16+8 bits × 2 registers/channel + AXI control)
- **LUTs**: ~50-100 (depending on target device)
- **I/O Pins**: 24 (16 + 8 pins)

## Verification

The design includes:
- Parameter validation at compile time
- Proper reset initialization
- AXI4-Lite protocol compliance
- GPIO functionality validation

### Tests and Examples

Comprehensive test files and example designs are provided:

- **`tb/tb_axi_lite_gpio.v`**: Complete testbench verifying AXI4-Lite protocol compliance and GPIO functionality
- **`examples/gpio_example_system.v`**: Full system example with LED control and button input
- **`Makefile`**: Build automation for running tests and examples
- **`TEST_README.md`**: Detailed documentation for tests and examples

To run tests:
```bash
# Run basic GPIO IP testbench
make test

# Run example system demonstration
make example

# Run all tests
make all
```

## License

This IP core is provided under the MIT License. See LICENSE file for details.