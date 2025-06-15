# AXI4-Lite SPI Controller

## Overview

The AXI4-Lite SPI Controller is a configurable Serial Peripheral Interface (SPI) master controller that provides an AXI4-Lite slave interface for system integration. This IP core allows software control of SPI communication with configurable modes and data widths.

## Features

- **SPI Master Interface**: Standard SPI master with SCLK, MOSI, MISO, and CS signals
- **Configurable SPI Modes**: Support for all 4 SPI modes (CPOL/CPHA combinations)
- **Variable Data Width**: Support for 8, 16, or 32-bit transfers
- **Configurable Clock Divider**: Software-configurable SPI clock frequency
- **AXI4-Lite Interface**: Standard AXI4-Lite slave interface for easy system integration
- **Chip Select Control**: Manual chip select control for multiple devices
- **Status Monitoring**: Busy and data ready status flags

## Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `ADDR_WIDTH` | int | 5 | ≥5 | AXI4-Lite address width |
| `CLK_FREQ` | int | 100000000 | >0 | Input clock frequency in Hz |
| `DEFAULT_CLKDIV` | int | 100 | ≥2 | Default clock divider for SPI clock |

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

### SPI Interface
- `spi_clk` - SPI Clock output
- `spi_mosi` - Master Out Slave In data output
- `spi_miso` - Master In Slave Out data input
- `spi_cs_n` - Chip Select output (active low)

## Register Map

| Address | Register Name | Access | Description |
|---------|---------------|--------|-------------|
| 0x00 | CTRL | R/W | Control Register |
| 0x04 | STATUS | R | Status Register |
| 0x08 | CLKDIV | R/W | Clock Divider Register |
| 0x0C | TXDATA | R/W | Transmit Data Register |
| 0x10 | RXDATA | R | Receive Data Register |
| 0x14 | CS | R/W | Chip Select Register |

### Register Descriptions

#### CTRL (Control Register - 0x00)
- **Bit 0 (ENABLE)**: SPI Enable (1 = enabled, 0 = disabled)
- **Bit 1 (CPOL)**: Clock Polarity (1 = idle high, 0 = idle low)
- **Bit 2 (CPHA)**: Clock Phase (1 = sample on trailing edge, 0 = sample on leading edge)
- **Bits 5:4 (WIDTH)**: Data Width (00 = 8-bit, 01 = 16-bit, 10 = 32-bit)
- **Bits 31:6**: Reserved
- **Reset Value**: 0x00000000

#### STATUS (Status Register - 0x04)
- **Bit 0 (BUSY)**: SPI Busy (1 = transaction in progress, 0 = idle)
- **Bit 1 (RXRDY)**: RX Data Ready (1 = new data available, 0 = no new data)
- **Bits 31:2**: Reserved
- **Reset Value**: 0x00000000

#### CLKDIV (Clock Divider Register - 0x08)
- **Bits 31:0**: Clock divider value (SPI_CLK = aclk / CLKDIV)
- **Reset Value**: DEFAULT_CLKDIV parameter value
- **Note**: Minimum value is 2

#### TXDATA (Transmit Data Register - 0x0C)
- **Bits 31:0**: Data to transmit
- **Reset Value**: 0x00000000
- **Note**: Writing to this register initiates an SPI transaction when SPI is enabled

#### RXDATA (Receive Data Register - 0x10)
- **Bits 31:0**: Last received data
- **Reset Value**: 0x00000000
- **Note**: Read-only register

#### CS (Chip Select Register - 0x14)
- **Bit 0**: Chip Select control (0 = CS active/low, 1 = CS inactive/high)
- **Bits 31:1**: Reserved
- **Reset Value**: 0x00000001 (CS inactive)

## SPI Modes

The controller supports all four standard SPI modes:

| Mode | CPOL | CPHA | Clock Idle | Data Sampling |
|------|------|------|------------|---------------|
| 0 | 0 | 0 | Low | Leading Edge |
| 1 | 0 | 1 | Low | Trailing Edge |
| 2 | 1 | 0 | High | Leading Edge |
| 3 | 1 | 1 | High | Trailing Edge |

## Usage Example

### Verilog Instantiation

```verilog
axi_lite_spi #(
    .ADDR_WIDTH(5),
    .CLK_FREQ(100000000),
    .DEFAULT_CLKDIV(100)
) spi_inst (
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
    
    // SPI interface
    .spi_clk(spi_clk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_cs_n(spi_cs_n)
);
```

### Software Programming Example (C)

```c
#define SPI_BASE_ADDR    0x40000000
#define SPI_CTRL_REG     (SPI_BASE_ADDR + 0x00)
#define SPI_STATUS_REG   (SPI_BASE_ADDR + 0x04)
#define SPI_CLKDIV_REG   (SPI_BASE_ADDR + 0x08)
#define SPI_TXDATA_REG   (SPI_BASE_ADDR + 0x0C)
#define SPI_RXDATA_REG   (SPI_BASE_ADDR + 0x10)
#define SPI_CS_REG       (SPI_BASE_ADDR + 0x14)

// Configure SPI for Mode 0, 8-bit transfers, 1MHz
void spi_init() {
    // Set clock divider (100MHz / 100 = 1MHz)
    *(volatile uint32_t*)SPI_CLKDIV_REG = 100;
    
    // Configure SPI: Enable, Mode 0 (CPOL=0, CPHA=0), 8-bit
    *(volatile uint32_t*)SPI_CTRL_REG = 0x01;  // Enable only
    
    // Activate chip select
    *(volatile uint32_t*)SPI_CS_REG = 0x00;
}

// Send and receive 8-bit data
uint8_t spi_transfer(uint8_t tx_data) {
    // Send data (this starts the transaction)
    *(volatile uint32_t*)SPI_TXDATA_REG = tx_data;
    
    // Wait for transaction to complete
    while (*(volatile uint32_t*)SPI_STATUS_REG & 0x01);
    
    // Read received data
    return *(volatile uint32_t*)SPI_RXDATA_REG & 0xFF;
}
```

## Implementation Details

### AXI4-Lite Protocol Compliance
- Supports 32-bit data width with byte enable strobes
- Implements proper AXI4-Lite handshaking protocols
- Provides OKAY responses for all valid transactions
- Address decoding based on bits [4:2] for 6-register map

### SPI Clock Generation
- Programmable clock divider generates SPI clock from system clock
- Minimum divider value is 2 (maximum SPI clock = aclk/2)
- Clock polarity and phase configurable via CTRL register

### Transaction Control
- Writing to TXDATA register automatically initiates SPI transaction when enabled
- Chip select can be controlled manually via CS register
- Busy flag indicates when transaction is in progress

### Reset Behavior
- All registers reset to safe default values
- SPI disabled and chip select inactive after reset
- Clock divider set to DEFAULT_CLKDIV parameter value

## Resource Utilization

Typical resource usage (may vary by target device and synthesis settings):
- Logic Elements: ~200-300 LEs
- Memory Bits: 0 (no embedded memory used)
- DSP Blocks: 0

## Verification

The IP core includes a comprehensive testbench that verifies:
- AXI4-Lite protocol compliance
- Register read/write functionality
- SPI mode configuration
- Basic SPI transactions
- Chip select control

Run tests using the included Makefile:
```bash
make test          # Run basic testbench
make wave-test     # Run test and view waveforms
make clean         # Clean generated files
```

## License

This project is licensed under the MIT License - see the main repository LICENSE file for details.