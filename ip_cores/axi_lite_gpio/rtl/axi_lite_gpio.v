/*
 * AXI4-Lite GPIO Controller
 * 
 * This module implements a configurable GPIO controller with AXI4-Lite slave interface.
 * Features:
 * - Configurable width (1 to 32 bits) and direction at compile time
 * - Support for up to 2 channels
 * - Individual pin direction control (input/output)
 * - AXI4-Lite compliant slave interface
 * 
 * Register Map:
 * 0x00: Channel 0 Data Register (R/W)
 * 0x04: Channel 0 Direction Register (R/W) - 1=output, 0=input
 * 0x08: Channel 1 Data Register (R/W) - if NUM_CHANNELS > 1
 * 0x0C: Channel 1 Direction Register (R/W) - if NUM_CHANNELS > 1
 */

module axi_lite_gpio #(
    parameter GPIO_WIDTH = 8,           // Width of each GPIO channel (1-32)
    parameter NUM_CHANNELS = 1,         // Number of GPIO channels (1-2)
    parameter ADDR_WIDTH = 4            // AXI address width (minimum 4 for register map)
) (
    // Clock and Reset
    input                           aclk,
    input                           aresetn,
    
    // AXI4-Lite Slave Interface
    // Write Address Channel
    input  [ADDR_WIDTH-1:0]         s_axi_awaddr,
    input  [2:0]                    s_axi_awprot,
    input                           s_axi_awvalid,
    output                          s_axi_awready,
    
    // Write Data Channel  
    input  [31:0]                   s_axi_wdata,
    input  [3:0]                    s_axi_wstrb,
    input                           s_axi_wvalid,
    output                          s_axi_wready,
    
    // Write Response Channel
    output [1:0]                    s_axi_bresp,
    output                          s_axi_bvalid,
    input                           s_axi_bready,
    
    // Read Address Channel
    input  [ADDR_WIDTH-1:0]         s_axi_araddr,
    input  [2:0]                    s_axi_arprot,
    input                           s_axi_arvalid,
    output                          s_axi_arready,
    
    // Read Data Channel
    output [31:0]                   s_axi_rdata,
    output [1:0]                    s_axi_rresp,
    output                          s_axi_rvalid,
    input                           s_axi_rready,
    
    // GPIO Interface
    input  [GPIO_WIDTH*NUM_CHANNELS-1:0]  gpio_i,   // GPIO input
    output [GPIO_WIDTH*NUM_CHANNELS-1:0]  gpio_o,   // GPIO output  
    output [GPIO_WIDTH*NUM_CHANNELS-1:0]  gpio_t    // GPIO tristate (1=input, 0=output)
);

    // Parameter validation
    initial begin
        if (GPIO_WIDTH < 1 || GPIO_WIDTH > 32) begin
            $error("GPIO_WIDTH must be between 1 and 32, got %0d", GPIO_WIDTH);
        end
        if (NUM_CHANNELS < 1 || NUM_CHANNELS > 2) begin
            $error("NUM_CHANNELS must be 1 or 2, got %0d", NUM_CHANNELS);
        end
        if (ADDR_WIDTH < 4) begin
            $error("ADDR_WIDTH must be at least 4 for register map, got %0d", ADDR_WIDTH);
        end
    end

    // Internal registers
    reg [GPIO_WIDTH*NUM_CHANNELS-1:0] gpio_data_reg;  // Data registers
    reg [GPIO_WIDTH*NUM_CHANNELS-1:0] gpio_dir_reg;   // Direction registers (1=output, 0=input)
    
    // AXI4-Lite interface signals
    reg                  axi_awready;
    reg                  axi_wready;
    reg [1:0]            axi_bresp;
    reg                  axi_bvalid;
    reg                  axi_arready;
    reg [31:0]           axi_rdata;
    reg [1:0]            axi_rresp;
    reg                  axi_rvalid;
    
    // Internal address registers
    reg [ADDR_WIDTH-1:0] axi_awaddr;
    reg [ADDR_WIDTH-1:0] axi_araddr;
    
    // AXI4-Lite Write Address Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready <= 1'b0;
            axi_awaddr <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                axi_awready <= 1'b1;
                axi_awaddr <= s_axi_awaddr;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end
    
    // AXI4-Lite Write Data Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && s_axi_wvalid && s_axi_awvalid) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end
    
    // Register writes
    integer ch_idx;
    always @(posedge aclk) begin
        if (!aresetn) begin
            gpio_data_reg <= {GPIO_WIDTH*NUM_CHANNELS{1'b0}};
            gpio_dir_reg <= {GPIO_WIDTH*NUM_CHANNELS{1'b0}};  // Default to all inputs
        end else begin
            if (axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid) begin
                case (axi_awaddr[3:2])
                    2'b00: begin  // Channel 0 Data Register
                        if (s_axi_wstrb[0]) 
                            gpio_data_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1] && GPIO_WIDTH > 8) 
                            gpio_data_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2] && GPIO_WIDTH > 16) 
                            gpio_data_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3] && GPIO_WIDTH > 24) 
                            gpio_data_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    2'b01: begin  // Channel 0 Direction Register
                        if (s_axi_wstrb[0]) 
                            gpio_dir_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1] && GPIO_WIDTH > 8) 
                            gpio_dir_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2] && GPIO_WIDTH > 16) 
                            gpio_dir_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3] && GPIO_WIDTH > 24) 
                            gpio_dir_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    2'b10: begin  // Channel 1 Data Register
                        if (NUM_CHANNELS > 1) begin
                            if (s_axi_wstrb[0]) 
                                gpio_data_reg[GPIO_WIDTH+7:GPIO_WIDTH] <= s_axi_wdata[7:0];
                            if (s_axi_wstrb[1] && GPIO_WIDTH > 8) 
                                gpio_data_reg[GPIO_WIDTH+15:GPIO_WIDTH+8] <= s_axi_wdata[15:8];
                            if (s_axi_wstrb[2] && GPIO_WIDTH > 16) 
                                gpio_data_reg[GPIO_WIDTH+23:GPIO_WIDTH+16] <= s_axi_wdata[23:16];
                            if (s_axi_wstrb[3] && GPIO_WIDTH > 24) 
                                gpio_data_reg[GPIO_WIDTH+31:GPIO_WIDTH+24] <= s_axi_wdata[31:24];
                        end
                    end
                    2'b11: begin  // Channel 1 Direction Register
                        if (NUM_CHANNELS > 1) begin
                            if (s_axi_wstrb[0]) 
                                gpio_dir_reg[GPIO_WIDTH+7:GPIO_WIDTH] <= s_axi_wdata[7:0];
                            if (s_axi_wstrb[1] && GPIO_WIDTH > 8) 
                                gpio_dir_reg[GPIO_WIDTH+15:GPIO_WIDTH+8] <= s_axi_wdata[15:8];
                            if (s_axi_wstrb[2] && GPIO_WIDTH > 16) 
                                gpio_dir_reg[GPIO_WIDTH+23:GPIO_WIDTH+16] <= s_axi_wdata[23:16];
                            if (s_axi_wstrb[3] && GPIO_WIDTH > 24) 
                                gpio_dir_reg[GPIO_WIDTH+31:GPIO_WIDTH+24] <= s_axi_wdata[31:24];
                        end
                    end
                endcase
            end
        end
    end
    
    // AXI4-Lite Write Response Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp <= 2'b00;
        end else begin
            if (axi_awready && s_axi_awvalid && axi_wready && s_axi_wvalid && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp <= 2'b00; // OKAY response
            end else begin
                if (s_axi_bready && axi_bvalid) begin
                    axi_bvalid <= 1'b0;
                end
            end
        end
    end
    
    // AXI4-Lite Read Address Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_arready <= 1'b0;
            axi_araddr <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (~axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
                axi_araddr <= s_axi_araddr;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end
    
    // AXI4-Lite Read Data Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_rvalid <= 1'b0;
            axi_rresp <= 2'b00;
        end else begin
            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp <= 2'b00; // OKAY response
            end else begin
                if (axi_rvalid && s_axi_rready) begin
                    axi_rvalid <= 1'b0;
                end
            end
        end
    end
    
    // Register reads
    integer i;
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_rdata <= 32'h00000000;
        end else begin
            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                case (axi_araddr[3:2])
                    2'b00: begin  // Channel 0 Data Register
                        axi_rdata <= 32'h00000000;
                        // For inputs, read from gpio_i; for outputs, read from gpio_data_reg
                        for (i = 0; i < GPIO_WIDTH; i = i + 1) begin
                            if (i < 32) begin
                                axi_rdata[i] <= gpio_dir_reg[i] ? gpio_data_reg[i] : gpio_i[i];
                            end
                        end
                    end
                    2'b01: begin  // Channel 0 Direction Register
                        axi_rdata <= 32'h00000000;
                        if (GPIO_WIDTH <= 32) begin
                            axi_rdata[GPIO_WIDTH-1:0] <= gpio_dir_reg[GPIO_WIDTH-1:0];
                        end else begin
                            axi_rdata[31:0] <= gpio_dir_reg[31:0];
                        end
                    end
                    2'b10: begin  // Channel 1 Data Register
                        axi_rdata <= 32'h00000000;
                        if (NUM_CHANNELS > 1) begin
                            for (i = 0; i < GPIO_WIDTH; i = i + 1) begin
                                if (i < 32) begin
                                    axi_rdata[i] <= gpio_dir_reg[GPIO_WIDTH+i] ? gpio_data_reg[GPIO_WIDTH+i] : gpio_i[GPIO_WIDTH+i];
                                end
                            end
                        end
                    end
                    2'b11: begin  // Channel 1 Direction Register
                        axi_rdata <= 32'h00000000;
                        if (NUM_CHANNELS > 1) begin
                            if (GPIO_WIDTH <= 32) begin
                                axi_rdata[GPIO_WIDTH-1:0] <= gpio_dir_reg[GPIO_WIDTH*2-1:GPIO_WIDTH];
                            end else begin
                                axi_rdata[31:0] <= gpio_dir_reg[GPIO_WIDTH+31:GPIO_WIDTH];
                            end
                        end
                    end
                endcase
            end
        end
    end
    
    // GPIO output assignments
    generate
        genvar ch;
        for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin : gen_gpio_channels
            assign gpio_o[GPIO_WIDTH*(ch+1)-1:GPIO_WIDTH*ch] = gpio_data_reg[GPIO_WIDTH*(ch+1)-1:GPIO_WIDTH*ch];
            assign gpio_t[GPIO_WIDTH*(ch+1)-1:GPIO_WIDTH*ch] = ~gpio_dir_reg[GPIO_WIDTH*(ch+1)-1:GPIO_WIDTH*ch];  // Invert: 1=input (tristate), 0=output
        end
    endgenerate
    
    // Assign outputs
    assign s_axi_awready = axi_awready;
    assign s_axi_wready = axi_wready;
    assign s_axi_bresp = axi_bresp;
    assign s_axi_bvalid = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata = axi_rdata;
    assign s_axi_rresp = axi_rresp;
    assign s_axi_rvalid = axi_rvalid;

endmodule