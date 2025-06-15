# Makefile for AXI4-Lite SPI IP Core Tests and Examples
#
# Usage:
#   make test          - Run basic SPI IP testbench
#   make clean         - Clean generated files
#   make all           - Run all tests
#   make help          - Show help message

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Directories
RTL_DIR = rtl
TB_DIR = tb
BUILD_DIR = build

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Basic SPI IP testbench
.PHONY: test
test: $(BUILD_DIR) $(BUILD_DIR)/tb_axi_lite_spi
	@echo "Running AXI4-Lite SPI IP testbench..."
	cd $(BUILD_DIR) && $(VVP) tb_axi_lite_spi

$(BUILD_DIR)/tb_axi_lite_spi: $(RTL_DIR)/axi_lite_spi.v $(TB_DIR)/tb_axi_lite_spi.v
	cd $(BUILD_DIR) && $(IVERILOG) -o tb_axi_lite_spi \
		-I../$(RTL_DIR) \
		../$(RTL_DIR)/axi_lite_spi.v \
		../$(TB_DIR)/tb_axi_lite_spi.v

# View waveforms (requires GTKWave)
.PHONY: wave-test
wave-test: test
	cd $(BUILD_DIR) && $(GTKWAVE) tb_axi_lite_spi.vcd &

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
	@echo "  test        - Run basic SPI IP testbench"
	@echo "  wave-test   - Run test and view waveforms"
	@echo "  all         - Run all tests"
	@echo "  clean       - Clean generated files"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - Icarus Verilog (iverilog, vvp)"
	@echo "  - GTKWave (optional, for waveform viewing)"

# Default target
.DEFAULT_GOAL := help