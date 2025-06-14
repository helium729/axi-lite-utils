/*
 * Testbench for GPIO Example System
 * 
 * This testbench demonstrates the complete system operation:
 * - Button inputs controlling LED patterns
 * - AXI4-Lite master automatically managing GPIO configuration
 */

`timescale 1ns / 1ps

module tb_gpio_example_system;

    // System signals
    reg        sys_clk;
    reg        sys_resetn;
    reg  [3:0] buttons;
    wire [7:0] leds;
    wire [31:0] axi_debug_data;
    wire        axi_debug_valid;
    
    // Clock generation (100MHz)
    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk;
    end
    
    // Device Under Test
    gpio_example_system #(
        .SYS_CLK_FREQ(100_000_000),
        .UPDATE_PERIOD(1000)  // Much faster for simulation (10us instead of 10ms)
    ) dut (
        .sys_clk(sys_clk),
        .sys_resetn(sys_resetn),
        .leds(leds),
        .buttons(buttons),
        .axi_debug_data(axi_debug_data),
        .axi_debug_valid(axi_debug_valid)
    );
    
    // Test stimulus
    initial begin
        $display("========================================");
        $display("Starting GPIO Example System Testbench");
        $display("========================================");
        
        // Initialize
        sys_resetn = 0;
        buttons = 4'b0000;
        
        // Reset sequence
        #1000;
        sys_resetn = 1;
        $display("System reset released");
        
        // Wait for system initialization
        #50000;
        $display("System initialization complete");
        
        // Test different button combinations
        $display("\n--- Testing Button Combinations ---");
        
        // Test single buttons
        $display("Testing single button presses...");
        buttons = 4'b0001;
        #200000;
        $display("Button[0] pressed - LEDs: %b (expected: 00000001)", leds);
        
        buttons = 4'b0010;
        #200000;
        $display("Button[1] pressed - LEDs: %b (expected: 00000011)", leds);
        
        buttons = 4'b0100;
        #200000;
        $display("Button[2] pressed - LEDs: %b (expected: 00001111)", leds);
        
        buttons = 4'b1000;
        #200000;
        $display("Button[3] pressed - LEDs: %b (expected: 11111111)", leds);
        
        // Test button combinations
        $display("Testing button combinations...");
        buttons = 4'b0011;
        #200000;
        $display("Buttons[0,1] pressed - LEDs: %b (expected: 10101010)", leds);
        
        buttons = 4'b1100;
        #200000;
        $display("Buttons[2,3] pressed - LEDs: %b (expected: 11110000)", leds);
        
        // Test no buttons
        buttons = 4'b0000;
        #200000;
        $display("No buttons pressed - LEDs: %b (expected: 00000000)", leds);
        
        // Test rapid button changes
        $display("\nTesting rapid button changes...");
        repeat (10) begin
            buttons = $random & 4'hF;
            #100000;
            $display("Random buttons: %b - LEDs: %b", buttons, leds);
        end
        
        $display("\n========================================");
        $display("Example System Test Complete");
        $display("========================================");
        
        #100000;
        $finish;
    end
    
    // Monitor AXI debug data (optional - comment out for cleaner output)
    // always @(posedge sys_clk) begin
    //     if (axi_debug_valid) begin
    //         $display("AXI Debug: Button data read = 0x%h", axi_debug_data);
    //     end
    // end
    
    // Timeout watchdog
    initial begin
        #5_000_000; // 5ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end
    
    // Optional waveform dump
    initial begin
        $dumpfile("tb_gpio_example_system.vcd");
        $dumpvars(0, tb_gpio_example_system);
    end

endmodule