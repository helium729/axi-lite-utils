/*
 * Example Design: Simple GPIO System with LEDs and Buttons
 * 
 * This example demonstrates how to integrate the AXI4-Lite GPIO IP
 * into a simple system with:
 * - Channel 0: 8-bit LED control (outputs)
 * - Channel 1: 4-bit button inputs
 * - Simple AXI4-Lite master for demonstration
 */

`timescale 1ns / 1ps

module gpio_example_system #(
    parameter SYS_CLK_FREQ = 100_000_000  // 100MHz system clock
) (
    // System clock and reset
    input  wire        sys_clk,
    input  wire        sys_resetn,
    
    // GPIO connections
    output wire [7:0]  leds,           // LED outputs (Channel 0)
    input  wire [3:0]  buttons,        // Button inputs (Channel 1)
    
    // Optional: External access to AXI interface for debugging
    output wire [31:0] axi_debug_data,
    output wire        axi_debug_valid
);

    // GPIO IP parameters
    localparam GPIO_WIDTH_CH0 = 8;  // 8 LEDs
    localparam GPIO_WIDTH_CH1 = 4;  // 4 buttons  
    localparam NUM_CHANNELS = 2;
    localparam ADDR_WIDTH = 4;
    
    // AXI4-Lite signals between master and GPIO IP
    wire [ADDR_WIDTH-1:0] s_axi_awaddr;
    wire [2:0]            s_axi_awprot;
    wire                  s_axi_awvalid;
    wire                  s_axi_awready;
    wire [31:0]           s_axi_wdata;
    wire [3:0]            s_axi_wstrb;
    wire                  s_axi_wvalid;
    wire                  s_axi_wready;
    wire [1:0]            s_axi_bresp;
    wire                  s_axi_bvalid;
    wire                  s_axi_bready;
    wire [ADDR_WIDTH-1:0] s_axi_araddr;
    wire [2:0]            s_axi_arprot;
    wire                  s_axi_arvalid;
    wire                  s_axi_arready;
    wire [31:0]           s_axi_rdata;
    wire [1:0]            s_axi_rresp;
    wire                  s_axi_rvalid;
    wire                  s_axi_rready;
    
    // GPIO interface signals
    wire [GPIO_WIDTH_CH0-1:0] gpio_io_i;    // LED channel inputs (not used)
    wire [GPIO_WIDTH_CH0-1:0] gpio_io_o;    // LED channel outputs
    wire [GPIO_WIDTH_CH0-1:0] gpio_io_t;    // LED channel tristate
    wire [GPIO_WIDTH_CH1-1:0] gpio2_io_i;   // Button channel inputs
    wire [GPIO_WIDTH_CH1-1:0] gpio2_io_o;   // Button channel outputs (not used)
    wire [GPIO_WIDTH_CH1-1:0] gpio2_io_t;   // Button channel tristate
    
    // Connect LEDs (Channel 0 - outputs only)
    assign leds = gpio_io_o;
    assign gpio_io_i = 8'h00;  // LED channel inputs tied to ground
    
    // Connect buttons (Channel 1 - inputs only)  
    assign gpio2_io_i = buttons;
    
    // AXI4-Lite GPIO IP instance
    axi_lite_gpio #(
        .GPIO_WIDTH_CH0(GPIO_WIDTH_CH0),
        .GPIO_WIDTH_CH1(GPIO_WIDTH_CH1),
        .NUM_CHANNELS(NUM_CHANNELS),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) gpio_ip (
        .aclk(sys_clk),
        .aresetn(sys_resetn),
        
        // AXI4-Lite slave interface
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
        
        // GPIO interface
        .gpio_io_i(gpio_io_i),      // LED inputs (unused)
        .gpio_io_o(gpio_io_o),      // LED outputs
        .gpio_io_t(gpio_io_t),      // LED tristate (should be all 0 for outputs)
        .gpio2_io_i(gpio2_io_i),    // Button inputs
        .gpio2_io_o(gpio2_io_o),    // Button outputs (unused)
        .gpio2_io_t(gpio2_io_t)     // Button tristate (should be all 1 for inputs)
    );
    
    // Simple AXI4-Lite master for demonstration
    // This master will:
    // 1. Configure Channel 0 (LEDs) as outputs
    // 2. Configure Channel 1 (buttons) as inputs  
    // 3. Periodically update LED pattern based on button state
    simple_axi_master #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_master (
        .aclk(sys_clk),
        .aresetn(sys_resetn),
        
        // AXI4-Lite master interface
        .m_axi_awaddr(s_axi_awaddr),
        .m_axi_awprot(s_axi_awprot),
        .m_axi_awvalid(s_axi_awvalid),
        .m_axi_awready(s_axi_awready),
        .m_axi_wdata(s_axi_wdata),
        .m_axi_wstrb(s_axi_wstrb),
        .m_axi_wvalid(s_axi_wvalid),
        .m_axi_wready(s_axi_wready),
        .m_axi_bresp(s_axi_bresp),
        .m_axi_bvalid(s_axi_bvalid),
        .m_axi_bready(s_axi_bready),
        .m_axi_araddr(s_axi_araddr),
        .m_axi_arprot(s_axi_arprot),
        .m_axi_arvalid(s_axi_arvalid),
        .m_axi_arready(s_axi_arready),
        .m_axi_rdata(s_axi_rdata),
        .m_axi_rresp(s_axi_rresp),
        .m_axi_rvalid(s_axi_rvalid),
        .m_axi_rready(s_axi_rready),
        
        // Debug outputs
        .debug_data(axi_debug_data),
        .debug_valid(axi_debug_valid)
    );

endmodule

/*
 * Simple AXI4-Lite Master
 * 
 * Demonstrates basic AXI4-Lite transactions:
 * - Initialize GPIO directions
 * - Read button states
 * - Update LED patterns
 */
module simple_axi_master #(
    parameter ADDR_WIDTH = 4
) (
    input  wire                   aclk,
    input  wire                   aresetn,
    
    // AXI4-Lite master interface
    output reg  [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output reg  [2:0]             m_axi_awprot,
    output reg                    m_axi_awvalid,
    input  wire                   m_axi_awready,
    output reg  [31:0]            m_axi_wdata,
    output reg  [3:0]             m_axi_wstrb,
    output reg                    m_axi_wvalid,
    input  wire                   m_axi_wready,
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output reg                    m_axi_bready,
    output reg  [ADDR_WIDTH-1:0]  m_axi_araddr,
    output reg  [2:0]             m_axi_arprot,
    output reg                    m_axi_arvalid,
    input  wire                   m_axi_arready,
    input  wire [31:0]            m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rvalid,
    output reg                    m_axi_rready,
    
    // Debug outputs
    output reg  [31:0]            debug_data,
    output reg                    debug_valid
);

    // Register addresses
    localparam CH0_DATA_REG = 4'h0;  // LED data
    localparam CH0_DIR_REG  = 4'h4;  // LED direction
    localparam CH1_DATA_REG = 4'h8;  // Button data
    localparam CH1_DIR_REG  = 4'hC;  // Button direction
    
    // State machine states
    localparam STATE_RESET       = 0;
    localparam STATE_INIT_LED_DIR = 1;
    localparam STATE_INIT_BTN_DIR = 2;
    localparam STATE_READ_BUTTONS = 3;
    localparam STATE_UPDATE_LEDS  = 4;
    localparam STATE_WAIT        = 5;
    
    reg [2:0] state;
    reg [23:0] wait_counter;
    reg [31:0] button_data;
    reg [7:0] led_pattern;
    
    // LED pattern generation based on buttons
    always @(*) begin
        case (button_data[3:0])
            4'b0001: led_pattern = 8'b00000001;  // Button 0: Single LED
            4'b0010: led_pattern = 8'b00000011;  // Button 1: Two LEDs
            4'b0100: led_pattern = 8'b00001111;  // Button 2: Four LEDs
            4'b1000: led_pattern = 8'b11111111;  // Button 3: All LEDs
            4'b0011: led_pattern = 8'b10101010;  // Buttons 0+1: Alternating
            4'b1100: led_pattern = 8'b11110000;  // Buttons 2+3: Half pattern
            default: led_pattern = 8'b00000000;  // No buttons: All off
        endcase
    end
    
    // Main state machine
    always @(posedge aclk) begin
        if (!aresetn) begin
            state <= STATE_RESET;
            wait_counter <= 0;
            button_data <= 0;
            debug_data <= 0;
            debug_valid <= 0;
            
            // AXI interface reset
            m_axi_awaddr <= 0;
            m_axi_awprot <= 0;
            m_axi_awvalid <= 0;
            m_axi_wdata <= 0;
            m_axi_wstrb <= 0;
            m_axi_wvalid <= 0;
            m_axi_bready <= 0;
            m_axi_araddr <= 0;
            m_axi_arprot <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready <= 0;
        end else begin
            debug_valid <= 0;  // Default
            
            case (state)
                STATE_RESET: begin
                    if (wait_counter < 100) begin
                        wait_counter <= wait_counter + 1;
                    end else begin
                        wait_counter <= 0;
                        state <= STATE_INIT_LED_DIR;
                    end
                end
                
                STATE_INIT_LED_DIR: begin
                    // Configure Channel 0 (LEDs) as all outputs
                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        m_axi_awaddr <= CH0_DIR_REG;
                        m_axi_awprot <= 3'b000;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata <= 32'h000000FF;  // All 8 bits as outputs
                        m_axi_wstrb <= 4'b1111;
                        m_axi_wvalid <= 1'b1;
                        m_axi_bready <= 1'b1;
                    end else if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid <= 1'b0;
                        m_axi_bready <= 1'b0;
                        state <= STATE_INIT_BTN_DIR;
                    end
                end
                
                STATE_INIT_BTN_DIR: begin
                    // Configure Channel 1 (Buttons) as all inputs
                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        m_axi_awaddr <= CH1_DIR_REG;
                        m_axi_awprot <= 3'b000;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata <= 32'h00000000;  // All 4 bits as inputs
                        m_axi_wstrb <= 4'b1111;
                        m_axi_wvalid <= 1'b1;
                        m_axi_bready <= 1'b1;
                    end else if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid <= 1'b0;
                        m_axi_bready <= 1'b0;
                        state <= STATE_READ_BUTTONS;
                    end
                end
                
                STATE_READ_BUTTONS: begin
                    // Read button states from Channel 1
                    if (!m_axi_arvalid) begin
                        m_axi_araddr <= CH1_DATA_REG;
                        m_axi_arprot <= 3'b000;
                        m_axi_arvalid <= 1'b1;
                        m_axi_rready <= 1'b1;
                    end else if (m_axi_rvalid && m_axi_rready) begin
                        button_data <= m_axi_rdata;
                        debug_data <= m_axi_rdata;
                        debug_valid <= 1'b1;
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready <= 1'b0;
                        state <= STATE_UPDATE_LEDS;
                    end
                end
                
                STATE_UPDATE_LEDS: begin
                    // Update LED pattern based on button state
                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        m_axi_awaddr <= CH0_DATA_REG;
                        m_axi_awprot <= 3'b000;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata <= {24'h000000, led_pattern};
                        m_axi_wstrb <= 4'b1111;
                        m_axi_wvalid <= 1'b1;
                        m_axi_bready <= 1'b1;
                    end else if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid <= 1'b0;
                        m_axi_bready <= 1'b0;
                        state <= STATE_WAIT;
                        wait_counter <= 0;
                    end
                end
                
                STATE_WAIT: begin
                    // Wait before next cycle (approximately 10ms at 100MHz)
                    if (wait_counter < 1_000_000) begin
                        wait_counter <= wait_counter + 1;
                    end else begin
                        wait_counter <= 0;
                        state <= STATE_READ_BUTTONS;
                    end
                end
                
            endcase
        end
    end

endmodule