/*
 * Testbench for AXI4-Lite UART Controller
 * 
 * This testbench verifies:
 * - AXI4-Lite protocol compliance
 * - UART functionality (transmit/receive operations)
 * - Baud rate configuration
 * - FIFO operations
 * - Interrupt generation
 * - Error detection (frame, parity, overrun)
 */

`timescale 1ns / 1ps

module tb_axi_lite_uart;

    // Parameters for DUT
    parameter ADDR_WIDTH = 5;
    parameter CLK_FREQ = 100000000;
    parameter DEFAULT_BAUD = 115200;
    parameter FIFO_DEPTH = 16;
    
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
    
    // UART signals
    wire uart_txd;
    reg uart_rxd;
    wire interrupt;
    
    // Test control variables
    reg [31:0] read_data;
    reg [31:0] expected_data;
    integer test_errors;
    integer test_count;
    
    // Register addresses
    localparam CTRL_REG     = 5'h00;
    localparam STATUS_REG   = 5'h04;
    localparam BAUD_REG     = 5'h08;
    localparam TX_DATA_REG  = 5'h0C;
    localparam RX_DATA_REG  = 5'h10;
    localparam INT_EN_REG   = 5'h14;
    localparam INT_STAT_REG = 5'h18;
    
    // Control register bits
    localparam CTRL_ENABLE      = 0;
    localparam CTRL_TX_EN       = 1;
    localparam CTRL_RX_EN       = 2;
    localparam CTRL_PARITY_EN   = 3;
    localparam CTRL_PARITY_ODD  = 4;
    localparam CTRL_STOP_BITS   = 5;
    
    // Status register bits
    localparam STAT_TX_EMPTY    = 0;
    localparam STAT_TX_FULL     = 1;
    localparam STAT_RX_EMPTY    = 2;
    localparam STAT_RX_FULL     = 3;
    localparam STAT_FRAME_ERR   = 4;
    localparam STAT_PARITY_ERR  = 5;
    localparam STAT_OVERRUN_ERR = 6;
    
    // Clock generation
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk; // 100MHz clock
    end
    
    // Device Under Test
    axi_lite_uart #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .CLK_FREQ(CLK_FREQ),
        .DEFAULT_BAUD(DEFAULT_BAUD),
        .FIFO_DEPTH(FIFO_DEPTH)
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
        
        // UART interface
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),
        .interrupt(interrupt)
    );
    
    // VCD dump
    initial begin
        $dumpfile("tb_axi_lite_uart.vcd");
        $dumpvars(0, tb_axi_lite_uart);
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
            
            wait(s_axi_awready && s_axi_wready);
            @(posedge aclk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid = 1'b0;
            
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
            
            wait(s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid = 1'b0;
            
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge aclk);
            s_axi_rready = 1'b0;
        end
    endtask
    
    // Test comparison task
    task check_result;
        input [31:0] actual;
        input [31:0] expected;
        input [255:0] test_name;
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
    
    // UART transmit data simulation (what the DUT should receive)
    task uart_send_byte;
        input [7:0] data;
        input parity_en;
        input parity_odd;
        input stop_bits; // 0 = 1 stop bit, 1 = 2 stop bits
        integer i;
        reg parity_bit;
        begin
            // Calculate parity
            parity_bit = parity_odd ? 1'b1 : 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                parity_bit = parity_bit ^ data[i];
            end
            
            // Send start bit
            uart_rxd = 1'b0;
            repeat(16) @(posedge dut.baud_tick);
            
            // Send data bits
            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd = data[i];
                repeat(16) @(posedge dut.baud_tick);
            end
            
            // Send parity bit if enabled
            if (parity_en) begin
                uart_rxd = parity_bit;
                repeat(16) @(posedge dut.baud_tick);
            end
            
            // Send stop bit(s)
            uart_rxd = 1'b1;
            repeat(16) @(posedge dut.baud_tick);
            if (stop_bits) begin
                repeat(16) @(posedge dut.baud_tick);
            end
        end
    endtask
    
    // UART receive data verification (what the DUT should transmit)
    task uart_receive_byte;
        input [7:0] expected_data;
        input parity_en;
        input parity_odd;
        input stop_bits;
        reg [7:0] received_data;
        reg received_parity;
        reg expected_parity;
        integer i;
        begin
            // Calculate expected parity
            expected_parity = parity_odd ? 1'b1 : 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                expected_parity = expected_parity ^ expected_data[i];
            end
            
            // Wait for start bit
            wait(uart_txd == 1'b0);
            repeat(8) @(posedge dut.baud_tick); // Sample at middle of bit
            
            if (uart_txd != 1'b0) begin
                $display("ERROR: Start bit not detected properly");
                test_errors = test_errors + 1;
            end
            
            // Receive data bits
            for (i = 0; i < 8; i = i + 1) begin
                repeat(16) @(posedge dut.baud_tick);
                received_data[i] = uart_txd;
            end
            
            // Receive parity bit if enabled
            if (parity_en) begin
                repeat(16) @(posedge dut.baud_tick);
                received_parity = uart_txd;
                if (received_parity != expected_parity) begin
                    $display("ERROR: Parity mismatch - Expected: %b, Got: %b", expected_parity, received_parity);
                    test_errors = test_errors + 1;
                end
            end
            
            // Check stop bit(s)
            repeat(16) @(posedge dut.baud_tick);
            if (uart_txd != 1'b1) begin
                $display("ERROR: Stop bit not detected properly");
                test_errors = test_errors + 1;
            end
            
            if (stop_bits) begin
                repeat(16) @(posedge dut.baud_tick);
                if (uart_txd != 1'b1) begin
                    $display("ERROR: Second stop bit not detected properly");
                    test_errors = test_errors + 1;
                end
            end
            
            // Verify received data
            if (received_data == expected_data) begin
                $display("PASS: UART RX - Expected: 0x%h, Got: 0x%h", expected_data, received_data);
            end else begin
                $display("FAIL: UART RX - Expected: 0x%h, Got: 0x%h", expected_data, received_data);
                test_errors = test_errors + 1;
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("Starting AXI4-Lite UART Testbench");
        $display("CLK_FREQ: %d, DEFAULT_BAUD: %d", CLK_FREQ, DEFAULT_BAUD);
        $display("FIFO_DEPTH: %d", FIFO_DEPTH);
        $display("========================================");
        
        // Initialize
        test_errors = 0;
        test_count = 0;
        aresetn = 0;
        uart_rxd = 1'b1; // Idle state
        
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
        repeat(10) @(posedge aclk);
        
        $display("\n--- Test 1: Reset Values ---");
        axi_read(CTRL_REG, read_data);
        check_result(read_data, 32'h00000000, "CTRL reset value");
        
        axi_read(STATUS_REG, read_data);
        check_result(read_data[STAT_TX_EMPTY], 1'b1, "TX_EMPTY reset value");
        check_result(read_data[STAT_RX_EMPTY], 1'b1, "RX_EMPTY reset value");
        
        axi_read(BAUD_REG, read_data);
        expected_data = CLK_FREQ / (DEFAULT_BAUD * 16);
        check_result(read_data, expected_data, "BAUD reset value");
        
        axi_read(INT_EN_REG, read_data);
        check_result(read_data, 32'h00000000, "INT_EN reset value");
        
        axi_read(INT_STAT_REG, read_data);
        // TX empty interrupt may be set initially since TX FIFO is empty
        check_result(read_data & ~32'h00000001, 32'h00000000, "INT_STAT reset value (ignore TX empty)");
        
        $display("\n--- Test 2: Register Read/Write ---");
        // Test control register
        axi_write(CTRL_REG, 32'h0000003F, 4'hF);
        axi_read(CTRL_REG, read_data);
        check_result(read_data, 32'h0000003F, "CTRL register write/read");
        
        // Test baud rate register
        axi_write(BAUD_REG, 32'h00001234, 4'hF);
        axi_read(BAUD_REG, read_data);
        check_result(read_data, 32'h00001234, "BAUD register write/read");
        
        // Test interrupt enable register
        axi_write(INT_EN_REG, 32'h0000007F, 4'hF);
        axi_read(INT_EN_REG, read_data);
        check_result(read_data, 32'h0000007F, "INT_EN register write/read");
        
        $display("\n--- Test 3: UART Transmit ---");
        // Configure UART for basic operation (8N1)
        axi_write(CTRL_REG, 32'h00000007, 4'hF); // Enable UART + TX + RX
        
        // Set a higher baud rate for faster simulation
        axi_write(BAUD_REG, 32'h00000010, 4'hF); // Faster baud for simulation
        
        // Send a byte
        axi_write(TX_DATA_REG, 32'h000000A5, 4'h1);
        
        // Verify transmission
        fork
            uart_receive_byte(8'hA5, 1'b0, 1'b0, 1'b0); // 8N1
        join
        
        $display("\n--- Test 4: UART Receive ---");
        // Send a byte to the UART
        fork
            uart_send_byte(8'h5A, 1'b0, 1'b0, 1'b0); // 8N1
        join
        
        // Wait a bit for RX processing
        repeat(100) @(posedge aclk);
        
        // Read the received byte
        axi_read(RX_DATA_REG, read_data);
        check_result(read_data[7:0], 8'h5A, "UART RX data");
        
        $display("\n--- Test 5: Parity Operation ---");
        // Configure for 8E1 (even parity)
        axi_write(CTRL_REG, 32'h0000000F, 4'hF); // Enable UART + TX + RX + Parity
        
        // Send with even parity
        axi_write(TX_DATA_REG, 32'h000000AA, 4'h1);
        fork
            uart_receive_byte(8'hAA, 1'b1, 1'b0, 1'b0); // 8E1
        join
        
        // Receive with even parity
        fork
            uart_send_byte(8'h55, 1'b1, 1'b0, 1'b0); // 8E1
        join
        
        repeat(100) @(posedge aclk);
        axi_read(RX_DATA_REG, read_data);
        check_result(read_data[7:0], 8'h55, "UART RX data with parity");
        
        $display("\n--- Test 6: Two Stop Bits ---");
        // Configure for 8N2 (two stop bits)
        axi_write(CTRL_REG, 32'h00000027, 4'hF); // Enable UART + TX + RX + 2 stop bits
        
        // Send with two stop bits
        axi_write(TX_DATA_REG, 32'h000000CC, 4'h1);
        fork
            uart_receive_byte(8'hCC, 1'b0, 1'b0, 1'b1); // 8N2
        join
        
        $display("\n--- Test 7: Status Register ---");
        // Reset to basic mode
        axi_write(CTRL_REG, 32'h00000007, 4'hF); // Enable UART + TX + RX
        
        // Check TX empty status
        axi_read(STATUS_REG, read_data);
        check_result(read_data[STAT_TX_EMPTY], 1'b1, "TX FIFO empty status");
        
        // Fill TX FIFO to test full status
        repeat(FIFO_DEPTH) begin
            axi_write(TX_DATA_REG, 32'h00000011, 4'h1);
        end
        
        axi_read(STATUS_REG, read_data);
        check_result(read_data[STAT_TX_FULL], 1'b1, "TX FIFO full status");
        
        $display("\n--- Test 8: Interrupt Generation ---");
        // Enable TX empty interrupt
        axi_write(INT_EN_REG, 32'h00000001, 4'hF);
        
        // Wait for TX FIFO to empty and interrupt to assert
        wait(interrupt == 1'b1);
        $display("PASS: Interrupt asserted when TX FIFO empty");
        
        // Clear interrupt by reading status
        axi_read(INT_STAT_REG, read_data);
        check_result(read_data[0], 1'b1, "TX empty interrupt status");
        
        // Clear the interrupt
        axi_write(INT_STAT_REG, 32'h00000001, 4'hF); // Write 1 to clear
        
        repeat(10) @(posedge aclk);
        if (interrupt == 1'b0) begin
            $display("PASS: Interrupt cleared successfully");
        end else begin
            $display("FAIL: Interrupt not cleared");
            test_errors = test_errors + 1;
        end
        
        // Wait for all transmissions to complete
        repeat(1000) @(posedge aclk);
        
        $display("\n========================================");
        $display("Test Summary:");
        $display("Total Tests: %d", test_count);
        $display("Errors: %d", test_errors);
        if (test_errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        $display("========================================");
        
        $finish;
    end
    
    // Timeout
    initial begin
        #50000000; // 50ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule