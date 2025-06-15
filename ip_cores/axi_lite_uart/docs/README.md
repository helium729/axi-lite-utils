# AXI4-Lite UART Controller

## Overview

The AXI4-Lite UART Controller is a configurable universal asynchronous receiver/transmitter (UART) peripheral that provides an AXI4-Lite slave interface for system integration. This IP core allows software control of UART communication with configurable baud rates, data formats, and interrupt support.

## Features

- **Configurable Baud Rate**: Software-configurable baud rate using clock divisor register
- **Standard UART Protocol**: Support for 8-bit data with configurable parity (none, even, odd) and stop bits (1 or 2)
- **FIFO Buffers**: Configurable depth TX/RX FIFOs to reduce interrupt overhead
- **AXI4-Lite Interface**: Standard AXI4-Lite slave interface for easy system integration
- **Interrupt Support**: Comprehensive interrupt generation for TX/RX events and error conditions
- **Error Detection**: Frame error, parity error, and overrun error detection
- **Parameter Validation**: Compile-time parameter validation for robustness

## Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `ADDR_WIDTH` | int | 5 | ≥5 | AXI4-Lite address width |
| `CLK_FREQ` | int | 100000000 | ≥1MHz | Input clock frequency in Hz |
| `DEFAULT_BAUD` | int | 115200 | 300-3M | Default baud rate |
| `FIFO_DEPTH` | int | 16 | ≥4, power of 2 | TX/RX FIFO depth |

## Interface Signals

### AXI4-Lite Slave Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `aclk` | Input | 1 | AXI clock |
| `aresetn` | Input | 1 | AXI reset (active low) |
| `s_axi_awaddr` | Input | ADDR_WIDTH | Write address |
| `s_axi_awprot` | Input | 3 | Write protection type |
| `s_axi_awvalid` | Input | 1 | Write address valid |
| `s_axi_awready` | Output | 1 | Write address ready |
| `s_axi_wdata` | Input | 32 | Write data |
| `s_axi_wstrb` | Input | 4 | Write strobes |
| `s_axi_wvalid` | Input | 1 | Write valid |
| `s_axi_wready` | Output | 1 | Write ready |
| `s_axi_bresp` | Output | 2 | Write response |
| `s_axi_bvalid` | Output | 1 | Write response valid |
| `s_axi_bready` | Input | 1 | Response ready |
| `s_axi_araddr` | Input | ADDR_WIDTH | Read address |
| `s_axi_arprot` | Input | 3 | Read protection type |
| `s_axi_arvalid` | Input | 1 | Read address valid |
| `s_axi_arready` | Output | 1 | Read address ready |
| `s_axi_rdata` | Output | 32 | Read data |
| `s_axi_rresp` | Output | 2 | Read response |
| `s_axi_rvalid` | Output | 1 | Read valid |
| `s_axi_rready` | Input | 1 | Read ready |

### UART Interface

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `uart_txd` | Output | 1 | UART transmit data |
| `uart_rxd` | Input | 1 | UART receive data |
| `interrupt` | Output | 1 | Interrupt output |

## Register Map

| Address | Register Name | Access | Description |
|---------|---------------|--------|-------------|
| 0x00 | CTRL | R/W | Control Register |
| 0x04 | STATUS | R | Status Register |
| 0x08 | BAUD_DIV | R/W | Baud Rate Divisor Register |
| 0x0C | TX_DATA | W | Transmit Data Register |
| 0x10 | RX_DATA | R | Receive Data Register |
| 0x14 | INT_EN | R/W | Interrupt Enable Register |
| 0x18 | INT_STAT | R/W1C | Interrupt Status Register |

### Register Descriptions

#### CTRL (Control Register - 0x00)
- **Bit 0 (ENABLE)**: UART Enable (1 = enabled, 0 = disabled)
- **Bit 1 (TX_EN)**: Transmit Enable (1 = enabled, 0 = disabled)
- **Bit 2 (RX_EN)**: Receive Enable (1 = enabled, 0 = disabled)
- **Bit 3 (PARITY_EN)**: Parity Enable (1 = enabled, 0 = disabled)
- **Bit 4 (PARITY_ODD)**: Parity Type (1 = odd, 0 = even)
- **Bit 5 (STOP_BITS)**: Stop Bits (1 = 2 stop bits, 0 = 1 stop bit)
- **Bits 31:6**: Reserved
- **Reset Value**: 0x00000000

#### STATUS (Status Register - 0x04)
- **Bit 0 (TX_EMPTY)**: TX FIFO Empty
- **Bit 1 (TX_FULL)**: TX FIFO Full
- **Bit 2 (RX_EMPTY)**: RX FIFO Empty
- **Bit 3 (RX_FULL)**: RX FIFO Full
- **Bit 4 (FRAME_ERR)**: Frame Error (sticky)
- **Bit 5 (PARITY_ERR)**: Parity Error (sticky)
- **Bit 6 (OVERRUN_ERR)**: Overrun Error (sticky)
- **Bits 31:7**: Reserved
- **Reset Value**: 0x00000005 (TX and RX FIFOs empty)

#### BAUD_DIV (Baud Rate Divisor Register - 0x08)
- **Bits 31:0**: Baud rate divisor value
- **Formula**: Divisor = CLK_FREQ / (Baud_Rate × 16)
- **Reset Value**: CLK_FREQ / (DEFAULT_BAUD × 16)

#### TX_DATA (Transmit Data Register - 0x0C)
- **Bits 7:0**: Data to transmit (write to TX FIFO)
- **Bits 31:8**: Reserved
- **Access**: Write only (reading returns 0)

#### RX_DATA (Receive Data Register - 0x10)
- **Bits 7:0**: Received data (read from RX FIFO)
- **Bits 31:8**: Reserved
- **Access**: Read only (writing has no effect)

#### INT_EN (Interrupt Enable Register - 0x14)
- **Bit 0**: TX Empty Interrupt Enable
- **Bit 1**: TX Full Interrupt Enable
- **Bit 2**: RX Empty Interrupt Enable
- **Bit 3**: RX Full Interrupt Enable
- **Bit 4**: Frame Error Interrupt Enable
- **Bit 5**: Parity Error Interrupt Enable
- **Bit 6**: Overrun Error Interrupt Enable
- **Bits 31:7**: Reserved
- **Reset Value**: 0x00000000

#### INT_STAT (Interrupt Status Register - 0x18)
- **Bit 0**: TX Empty Interrupt Status
- **Bit 1**: TX Full Interrupt Status
- **Bit 2**: RX Empty Interrupt Status
- **Bit 3**: RX Full Interrupt Status
- **Bit 4**: Frame Error Interrupt Status
- **Bit 5**: Parity Error Interrupt Status
- **Bit 6**: Overrun Error Interrupt Status
- **Bits 31:7**: Reserved
- **Access**: Write 1 to clear (W1C)
- **Reset Value**: 0x00000001 (TX empty interrupt initially set)

## Usage Example

### Verilog Instantiation

```verilog
axi_lite_uart #(
    .ADDR_WIDTH(5),          // 5-bit address
    .CLK_FREQ(100000000),    // 100MHz clock
    .DEFAULT_BAUD(115200),   // 115200 baud
    .FIFO_DEPTH(16)          // 16-entry FIFOs
) uart_inst (
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
    
    // UART interface
    .uart_txd(uart_tx),
    .uart_rxd(uart_rx),
    .interrupt(uart_interrupt)
);
```

### Software Programming Example (C)

```c
// Base address of UART peripheral
#define UART_BASE_ADDR 0x40010000

// Register offsets
#define CTRL_REG       (UART_BASE_ADDR + 0x00)
#define STATUS_REG     (UART_BASE_ADDR + 0x04)
#define BAUD_DIV_REG   (UART_BASE_ADDR + 0x08)
#define TX_DATA_REG    (UART_BASE_ADDR + 0x0C)
#define RX_DATA_REG    (UART_BASE_ADDR + 0x10)
#define INT_EN_REG     (UART_BASE_ADDR + 0x14)
#define INT_STAT_REG   (UART_BASE_ADDR + 0x18)

// Control register bits
#define CTRL_ENABLE     (1 << 0)
#define CTRL_TX_EN      (1 << 1)
#define CTRL_RX_EN      (1 << 2)
#define CTRL_PARITY_EN  (1 << 3)
#define CTRL_PARITY_ODD (1 << 4)
#define CTRL_STOP_BITS  (1 << 5)

// Status register bits
#define STAT_TX_EMPTY   (1 << 0)
#define STAT_TX_FULL    (1 << 1)
#define STAT_RX_EMPTY   (1 << 2)
#define STAT_RX_FULL    (1 << 3)

// Initialize UART for 9600 baud, 8N1
void uart_init() {
    // Calculate baud rate divisor for 9600 baud
    uint32_t divisor = 100000000 / (9600 * 16);
    *(volatile uint32_t*)BAUD_DIV_REG = divisor;
    
    // Enable UART with TX and RX
    *(volatile uint32_t*)CTRL_REG = CTRL_ENABLE | CTRL_TX_EN | CTRL_RX_EN;
    
    // Enable TX empty and RX full interrupts
    *(volatile uint32_t*)INT_EN_REG = (1 << 0) | (1 << 3);
}

// Send a byte
void uart_send_byte(uint8_t data) {
    // Wait for TX FIFO to have space
    while (*(volatile uint32_t*)STATUS_REG & STAT_TX_FULL);
    
    // Write data to TX FIFO
    *(volatile uint32_t*)TX_DATA_REG = data;
}

// Receive a byte (blocking)
uint8_t uart_receive_byte() {
    // Wait for RX FIFO to have data
    while (*(volatile uint32_t*)STATUS_REG & STAT_RX_EMPTY);
    
    // Read data from RX FIFO
    return *(volatile uint32_t*)RX_DATA_REG & 0xFF;
}

// Send a string
void uart_send_string(const char* str) {
    while (*str) {
        uart_send_byte(*str++);
    }
}
```

## Implementation Details

### AXI4-Lite Protocol Compliance
- Supports 32-bit data width with byte enable strobes
- Implements proper AXI4-Lite handshaking protocols
- Provides OKAY responses for all valid transactions
- Address decoding based on bits [4:2] for 7-register map

### UART Protocol Support
- Standard asynchronous serial communication
- Configurable data format: 8 data bits with optional parity and 1-2 stop bits
- 16x oversampling for accurate bit timing
- Automatic start/stop bit generation and detection

### FIFO Management
- Separate TX and RX FIFOs with configurable depth
- Gray code pointers for reliable full/empty detection
- Automatic FIFO management during register access

### Baud Rate Generation
- Software-configurable baud rate using divisor register
- Formula: Baud Rate = CLK_FREQ / (Divisor × 16)
- 16x oversampling provides good timing tolerance

### Interrupt System
- Multiple interrupt sources: FIFO status and error conditions
- Individual interrupt enable/disable control
- Write-1-to-clear interrupt status register
- Combined interrupt output for system integration

### Error Detection
- Frame error: Invalid stop bit detection
- Parity error: Parity mismatch detection (when enabled)
- Overrun error: RX FIFO overflow detection
- Sticky error flags that persist until cleared by software

## Resource Utilization

The resource utilization will vary based on parameters:
- **FIFO_DEPTH**: Directly affects memory usage for TX/RX buffers
- **ADDR_WIDTH**: Minimal impact on resources
- **CLK_FREQ/DEFAULT_BAUD**: Affects baud rate divisor width

Typical utilization for default configuration (100MHz, 115200 baud, 16-entry FIFOs):
- **Registers**: ~200-300 bits (control, status, FIFOs, state machines)
- **LUTs**: ~150-250 (depending on target device)
- **Memory**: 32 bytes (2 × 16-entry × 8-bit FIFOs)
- **I/O Pins**: 3 (TX, RX, interrupt)

## Verification

The IP core includes a comprehensive testbench that verifies:
- AXI4-Lite protocol compliance
- Register read/write operations
- UART transmit and receive functionality
- Baud rate configuration
- Parity and stop bit options
- FIFO operations
- Interrupt generation and clearing
- Error detection and reporting

## License

This project is licensed under the MIT License - see the LICENSE file for details.