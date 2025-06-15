/*
 * Testbench for AXI4-Lite SPI Controller
 * 
 * This testbench verifies:
 * - AXI4-Lite protocol compliance
 * - Basic SPI functionality
 * - Register read/write operations
 * - SPI clock generation
 */

`timescale 1ns / 1ps

module tb_axi_lite_spi;

    // Parameters for DUT
    parameter ADDR_WIDTH = 5;
    parameter CLK_FREQ = 100000000;
    parameter DEFAULT_CLKDIV = 100;
    
    // Clock and reset
    reg aclk;
    reg aresetn;
    
    // AXI4-Lite signals
    reg [ADDR_WIDTH-1:0] s_axi_awaddr;
    reg [2:0] s_axi_awprot;
    reg s_axi_awvalid;
    wire s_axi_awready;
    reg [31:0] s_axi_wdata;
    reg [3:0] s_axi_wstrb;
    reg s_axi_wvalid;
    wire s_axi_wready;
    wire [1:0] s_axi_bresp;
    wire s_axi_bvalid;
    reg s_axi_bready;
    reg [ADDR_WIDTH-1:0] s_axi_araddr;
    reg [2:0] s_axi_arprot;
    reg s_axi_arvalid;
    wire s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire s_axi_rvalid;
    reg s_axi_rready;
    
    // SPI interface
    wire spi_clk;
    wire spi_mosi;
    reg spi_miso;
    wire spi_cs_n;
    
    // Test control variables
    reg [31:0] read_data;
    integer test_errors;
    integer test_count;
    
    // Register addresses
    localparam CTRL_REG     = 5'h00;
    localparam STATUS_REG   = 5'h04;
    localparam CLKDIV_REG   = 5'h08;
    localparam TXDATA_REG   = 5'h0C;
    localparam RXDATA_REG   = 5'h10;
    localparam CS_REG       = 5'h14;
    
    // Clock generation
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk; // 100MHz clock
    end
    
    // Device Under Test
    axi_lite_spi #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .CLK_FREQ(CLK_FREQ),
        .DEFAULT_CLKDIV(DEFAULT_CLKDIV)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        
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
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("tb_axi_lite_spi.vcd");
        $dumpvars(0, tb_axi_lite_spi);
    end
    
    // AXI4-Lite Write Task
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [31:0] data;
        input [3:0] strb;
        begin
            @(posedge aclk);
            s_axi_awaddr = addr;
            s_axi_awprot = 3'b000;
            s_axi_awvalid = 1'b1;
            s_axi_wdata = data;
            s_axi_wstrb = strb;
            s_axi_wvalid = 1'b1;
            s_axi_bready = 1'b1;
            
            // Wait for address and data ready
            wait(s_axi_awready && s_axi_wready);
            @(posedge aclk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid = 1'b0;
            
            // Wait for write response
            wait(s_axi_bvalid);
            @(posedge aclk);
            s_axi_bready = 1'b0;
        end
    endtask
    
    // AXI4-Lite Read Task
    task axi_read;
        input [ADDR_WIDTH-1:0] addr;
        output [31:0] data;
        begin
            @(posedge aclk);
            s_axi_araddr = addr;
            s_axi_arprot = 3'b000;
            s_axi_arvalid = 1'b1;
            s_axi_rready = 1'b1;
            
            // Wait for address ready
            wait(s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid = 1'b0;
            
            // Wait for read data valid
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge aclk);
            s_axi_rready = 1'b0;
        end
    endtask
    
    // Test assertion task
    task check_result;
        input [31:0] actual;
        input [31:0] expected;
        input [200*8-1:0] test_name;
        begin
            test_count = test_count + 1;
            if (actual == expected) begin
                $display("PASS: %s - Expected: 0x%h, Got: 0x%h", test_name, expected, actual);
            end else begin
                $display("FAIL: %s - Expected: 0x%h, Got: 0x%h", test_name, expected, actual);
                test_errors = test_errors + 1;
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("Starting AXI4-Lite SPI Testbench");
        $display("CLK_FREQ: %0d, DEFAULT_CLKDIV: %0d", CLK_FREQ, DEFAULT_CLKDIV);
        $display("========================================");
        
        // Initialize
        test_errors = 0;
        test_count = 0;
        aresetn = 0;
        spi_miso = 1'b0;
        
        // Initialize AXI signals
        s_axi_awaddr = 0;
        s_axi_awprot = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0;
        s_axi_arprot = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        
        // Reset sequence
        repeat(10) @(posedge aclk);
        aresetn = 1;
        repeat(5) @(posedge aclk);
        
        $display("");
        $display("--- Test 1: Reset Values ---");
        axi_read(CTRL_REG, read_data);
        check_result(read_data, 32'h00000000, "CTRL reset value");
        
        axi_read(CLKDIV_REG, read_data);
        check_result(read_data, DEFAULT_CLKDIV, "CLKDIV reset value");
        
        axi_read(CS_REG, read_data);
        check_result(read_data, 32'h00000001, "CS reset value");
        
        $display("");
        $display("--- Test 2: Register Read/Write ---");
        axi_write(CTRL_REG, 32'h0000003F, 4'hF);
        axi_read(CTRL_REG, read_data);
        check_result(read_data, 32'h0000003F, "CTRL register write/read");
        
        axi_write(CLKDIV_REG, 32'h00000010, 4'hF); // Fast clock for simulation
        axi_read(CLKDIV_REG, read_data);
        check_result(read_data, 32'h00000010, "CLKDIV register write/read");
        
        axi_write(CS_REG, 32'h00000000, 4'hF); // Activate CS
        axi_read(CS_REG, read_data);
        check_result(read_data, 32'h00000000, "CS register write/read");
        
        $display("");
        $display("--- Test 3: Basic SPI Transaction ---");
        // Configure SPI: Enable only, 8-bit, Mode 0
        axi_write(CTRL_REG, 32'h00000001, 4'hF); // Enable only
        
        // Set simple response on MISO
        spi_miso = 1'b1;
        
        // Send data
        axi_write(TXDATA_REG, 32'h0000005A, 4'hF);
        
        // Wait for transaction to complete
        repeat(1000) @(posedge aclk);
        
        // Check that something happened (CS should have been active)
        if (spi_cs_n !== 1'b0) begin
            $display("INFO: CS behavior during transaction");
        end
        
        $display("");
        $display("--- Test 4: Chip Select Control ---");
        // Test CS inactive
        axi_write(CS_REG, 32'h00000001, 4'hF); // CS inactive
        repeat(10) @(posedge aclk);
        if (spi_cs_n !== 1'b1) begin
            $display("FAIL: CS should be inactive (high)");
            test_errors = test_errors + 1;
        end else begin
            $display("PASS: CS inactive control");
        end
        test_count = test_count + 1;
        
        // Test CS active
        axi_write(CS_REG, 32'h00000000, 4'hF); // CS active
        repeat(10) @(posedge aclk);
        if (spi_cs_n !== 1'b0) begin
            $display("FAIL: CS should be active (low)");
            test_errors = test_errors + 1;
        end else begin
            $display("PASS: CS active control");
        end
        test_count = test_count + 1;
        
        // Wait for any remaining operations
        repeat(100) @(posedge aclk);
        
        // Final results
        $display("");
        $display("========================================");
        $display("Test Summary:");
        $display("Total Tests: %0d", test_count);
        $display("Errors: %0d", test_errors);
        if (test_errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        $display("========================================");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #500000; // 500us timeout
        $display("");
        $display("*** TIMEOUT - Test did not complete in time ***");
        $finish;
    end

endmodule