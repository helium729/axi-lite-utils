# Tests and Examples

This directory contains test files and example designs for the AXI4-Lite GPIO IP core.

## Directory Structure

```
├── tb/                           # Testbenches
│   └── tb_axi_lite_gpio.v       # Comprehensive GPIO IP testbench
├── examples/                     # Example designs
│   ├── gpio_example_system.v    # Complete system example
│   └── tb_gpio_example_system.v # Example system testbench
├── Makefile                      # Build automation
└── TEST_README.md               # This file
```

## Quick Start

### Prerequisites

- **Icarus Verilog**: For simulation (`sudo apt install iverilog` on Ubuntu)
- **GTKWave**: For waveform viewing (`sudo apt install gtkwave` on Ubuntu)

### Running Tests

```bash
# Run basic GPIO IP testbench
make test

# Run example system demonstration
make example

# Run all tests
make all

# View waveforms (after running tests)
make wave-test      # View basic testbench waveforms
make wave-example   # View example system waveforms

# Clean generated files
make clean
```

## Test Files

### tb_axi_lite_gpio.v

Comprehensive testbench that verifies:

- **AXI4-Lite Protocol Compliance**
  - Proper handshaking for read/write transactions
  - Correct response codes (OKAY)
  - Address decoding

- **GPIO Functionality**
  - Output pin control via data registers
  - Input pin reading 
  - Direction register configuration
  - Tristate control logic

- **Multi-Channel Operation**
  - Independent operation of Channel 0 and Channel 1
  - Different widths per channel
  - Proper channel isolation

- **Reset Behavior**
  - All registers initialize to safe values
  - All pins default to input mode

- **Byte Enable Support**
  - Partial register updates via AXI write strobes

**Expected Output:**
```
========================================
Starting AXI4-Lite GPIO Testbench
GPIO_WIDTH_CH0: 16, GPIO_WIDTH_CH1: 8
NUM_CHANNELS: 2
========================================

--- Test 1: Reset Values ---
PASS: CH0_DATA reset value - Expected: 0x00000000, Got: 0x00000000
PASS: CH0_DIR reset value - Expected: 0x00000000, Got: 0x00000000
...

========================================
Test Summary:
Total Tests: XX
Errors: 0
ALL TESTS PASSED!
========================================
```

## Example Designs

### gpio_example_system.v

Complete system example demonstrating practical GPIO usage:

**Features:**
- **8-bit LED Control** (Channel 0): All pins configured as outputs
- **4-bit Button Input** (Channel 1): All pins configured as inputs
- **Automatic Configuration**: Built-in AXI master handles setup
- **Pattern Generation**: Different LED patterns based on button combinations

**Button to LED Mapping:**
- Button 0: Single LED on
- Button 1: Two LEDs on
- Button 2: Four LEDs on  
- Button 3: All LEDs on
- Buttons 0+1: Alternating pattern (10101010)
- Buttons 2+3: Half pattern (11110000)
- No buttons: All LEDs off

**Components:**
- `gpio_example_system`: Top-level system module
- `simple_axi_master`: Demonstrates AXI4-Lite master implementation
- Automatic initialization and periodic updates

### tb_gpio_example_system.v

Testbench for the example system that:
- Simulates button presses
- Verifies LED patterns
- Monitors AXI transactions
- Tests various button combinations

## Using the Examples

### Hardware Integration

To use the example system in hardware:

1. **Connect LEDs** to `leds[7:0]` output pins
2. **Connect Buttons** to `buttons[3:0]` input pins  
3. **Provide Clock** to `sys_clk` (100MHz recommended)
4. **Connect Reset** to `sys_resetn` (active low)

### Software Integration

The example shows how to create an AXI4-Lite master. For processor-based systems:

```c
// Register addresses
#define GPIO_BASE       0x40000000
#define CH0_DATA_REG    (GPIO_BASE + 0x00)  // LED control
#define CH0_DIR_REG     (GPIO_BASE + 0x04)  // LED direction
#define CH1_DATA_REG    (GPIO_BASE + 0x08)  // Button reading
#define CH1_DIR_REG     (GPIO_BASE + 0x0C)  // Button direction

// Initialize GPIO
void gpio_init() {
    *(volatile uint32_t*)CH0_DIR_REG = 0x000000FF;  // LEDs as outputs
    *(volatile uint32_t*)CH1_DIR_REG = 0x00000000;  // Buttons as inputs
}

// Control LEDs
void set_leds(uint8_t pattern) {
    *(volatile uint32_t*)CH0_DATA_REG = pattern;
}

// Read buttons  
uint8_t read_buttons() {
    return *(volatile uint32_t*)CH1_DATA_REG & 0x0F;
}
```

## Advanced Testing

### Custom Test Parameters

The testbench can be customized for different configurations:

```verilog
// Modify these parameters in tb_axi_lite_gpio.v
parameter GPIO_WIDTH_CH0 = 32;  // Test with 32-bit channel
parameter GPIO_WIDTH_CH1 = 16;  // Test with 16-bit channel  
parameter NUM_CHANNELS = 1;     // Test single-channel mode
```

### Timing Analysis

Both testbenches include timing verification:
- Setup/hold time checking
- Clock domain crossing validation
- AXI protocol timing compliance

### Debug Features

- **Waveform Generation**: VCD files for signal analysis
- **Debug Outputs**: AXI transaction monitoring
- **Verbose Logging**: Detailed test progress information

## Troubleshooting

### Common Issues

1. **Simulation Fails to Start**
   - Check that Icarus Verilog is installed: `iverilog -V`
   - Verify file paths in Makefile

2. **Tests Fail**
   - Check parameter compatibility
   - Verify GPIO widths don't exceed 32 bits
   - Ensure NUM_CHANNELS is 1 or 2

3. **Waveforms Don't Open**
   - Install GTKWave: `sudo apt install gtkwave`
   - Check that VCD files are generated in build directory

### Getting Help

For issues with the IP core or examples:
1. Check the main documentation in `docs/README.md`
2. Review test output for specific error messages
3. Use waveform viewer to debug signal behavior
4. Verify parameter settings match your requirements