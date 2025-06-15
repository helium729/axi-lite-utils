# axi-lite-utils
Verilog IP cores for AXI4-Lite based designs

## Available IP Cores

### AXI4-Lite GPIO Controller
**Location**: `ip_cores/axi_lite_gpio/`

A configurable GPIO controller with AXI4-Lite slave interface.

**Features:**
- Configurable width (1-32 bits) and up to 2 channels
- Individual pin direction control (input/output)
- Standard AXI4-Lite slave interface
- Proper tristate control for bidirectional pins

**Documentation**: [AXI4-Lite GPIO README](ip_cores/axi_lite_gpio/docs/README.md)

### AXI4-Lite UART Controller
**Location**: `ip_cores/axi_lite_uart/`

A configurable UART controller with AXI4-Lite slave interface.

**Features:**
- Configurable baud rate and clock frequency
- Standard UART protocol (8-bit data, configurable parity and stop bits)
- TX/RX FIFO buffers with configurable depth
- Comprehensive interrupt support
- Error detection (frame, parity, overrun errors)
- Standard AXI4-Lite slave interface

**Documentation**: [AXI4-Lite UART README](ip_cores/axi_lite_uart/docs/README.md)

## Repository Structure

```
axi-lite-utils/
├── ip_cores/                    # IP core implementations
│   ├── axi_lite_gpio/          # AXI4-Lite GPIO Controller
│   │   ├── rtl/                # RTL source files
│   │   ├── tb/                 # Testbenches
│   │   └── docs/               # Documentation
│   └── axi_lite_uart/          # AXI4-Lite UART Controller
│       ├── rtl/                # RTL source files
│       ├── tb/                 # Testbenches
│       └── docs/               # Documentation
├── LICENSE                     # MIT License
└── README.md                   # This file
```

## Usage

Each IP core is self-contained in its respective directory with:
- RTL source files in the `rtl/` subdirectory
- Testbenches in the `tb/` subdirectory
- Documentation in the `docs/` subdirectory
- Examples and usage information in the IP-specific README
- Makefile for building and testing (using Icarus Verilog)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
