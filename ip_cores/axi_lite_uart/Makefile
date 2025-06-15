# Makefile for AXI4-Lite UART IP Core Tests and Examples
#
# Usage:
#   make test          - Run basic UART IP testbench
#   make example       - Run example system testbench  
#   make clean         - Clean generated files
#   make all           - Run all tests and examples

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TB_DIR = tb
EXAMPLE_DIR = examples
BUILD_DIR = build

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Basic UART IP testbench
.PHONY: test
test: $(BUILD_DIR) $(BUILD_DIR)/tb_axi_lite_uart
	@echo "Running AXI4-Lite UART IP testbench..."
	cd $(BUILD_DIR) && $(VVP) tb_axi_lite_uart

$(BUILD_DIR)/tb_axi_lite_uart: $(RTL_DIR)/axi_lite_uart.v $(TB_DIR)/tb_axi_lite_uart.v
	cd $(BUILD_DIR) && $(IVERILOG) -o tb_axi_lite_uart \
		-I../$(RTL_DIR) \
		../$(RTL_DIR)/axi_lite_uart.v \
		../$(TB_DIR)/tb_axi_lite_uart.v

# Example system testbench
.PHONY: example
example: $(BUILD_DIR) $(BUILD_DIR)/tb_uart_example_system
	@echo "Running UART example system testbench..."
	cd $(BUILD_DIR) && $(VVP) tb_uart_example_system

$(BUILD_DIR)/tb_uart_example_system: $(RTL_DIR)/axi_lite_uart.v $(EXAMPLE_DIR)/uart_example_system.v $(EXAMPLE_DIR)/tb_uart_example_system.v
	cd $(BUILD_DIR) && $(IVERILOG) -o tb_uart_example_system \
		-I../$(RTL_DIR) \
		../$(RTL_DIR)/axi_lite_uart.v \
		../$(EXAMPLE_DIR)/uart_example_system.v \
		../$(EXAMPLE_DIR)/tb_uart_example_system.v

# View waveforms (requires GTKWave)
.PHONY: wave-test
wave-test: test
	cd $(BUILD_DIR) && $(GTKWAVE) tb_axi_lite_uart.vcd &

.PHONY: wave-example  
wave-example: example
	cd $(BUILD_DIR) && $(GTKWAVE) tb_uart_example_system.vcd &

# Run all tests
.PHONY: all
all: test
	@echo "All tests completed successfully!"

# Clean generated files
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

# Help
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  test        - Run basic UART IP testbench"
	@echo "  example     - Run example system testbench"
	@echo "  wave-test   - Run test and view waveforms"
	@echo "  wave-example- Run example and view waveforms"
	@echo "  all         - Run all tests and examples"
	@echo "  clean       - Clean generated files"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - Icarus Verilog (iverilog, vvp)"
	@echo "  - GTKWave (optional, for waveform viewing)"

# Default target
.DEFAULT_GOAL := help