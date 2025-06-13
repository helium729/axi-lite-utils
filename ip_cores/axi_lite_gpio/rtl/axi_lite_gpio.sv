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
    parameter int GPIO_WIDTH = 8,           // Width of each GPIO channel (1-32)
    parameter int NUM_CHANNELS = 1,         // Number of GPIO channels (1-2)
    parameter int ADDR_WIDTH = 4            // AXI address width (minimum 4 for register map)
) (
    // Clock and Reset
    input  logic                    aclk,
    input  logic                    aresetn,
    
    // AXI4-Lite Slave Interface
    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic [2:0]             s_axi_awprot,
    input  logic                   s_axi_awvalid,
    output logic                   s_axi_awready,
    
    // Write Data Channel  
    input  logic [31:0]            s_axi_wdata,
    input  logic [3:0]             s_axi_wstrb,
    input  logic                   s_axi_wvalid,
    output logic                   s_axi_wready,
    
    // Write Response Channel
    output logic [1:0]             s_axi_bresp,
    output logic                   s_axi_bvalid,
    input  logic                   s_axi_bready,
    
    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic [2:0]             s_axi_arprot,
    input  logic                   s_axi_arvalid,
    output logic                   s_axi_arready,
    
    // Read Data Channel
    output logic [31:0]            s_axi_rdata,
    output logic [1:0]             s_axi_rresp,
    output logic                   s_axi_rvalid,
    input  logic                   s_axi_rready,
    
    // GPIO Interface
    input  logic [GPIO_WIDTH-1:0]  gpio_i [NUM_CHANNELS-1:0],   // GPIO input
    output logic [GPIO_WIDTH-1:0]  gpio_o [NUM_CHANNELS-1:0],   // GPIO output  
    output logic [GPIO_WIDTH-1:0]  gpio_t [NUM_CHANNELS-1:0]    // GPIO tristate (1=input, 0=output)
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
    logic [GPIO_WIDTH-1:0] gpio_data_reg [NUM_CHANNELS-1:0];  // Data registers
    logic [GPIO_WIDTH-1:0] gpio_dir_reg [NUM_CHANNELS-1:0];   // Direction registers (1=output, 0=input)
    
    // AXI4-Lite interface signals
    logic                  axi_awready;
    logic                  axi_wready;
    logic [1:0]            axi_bresp;
    logic                  axi_bvalid;
    logic                  axi_arready;
    logic [31:0]           axi_rdata;
    logic [1:0]            axi_rresp;
    logic                  axi_rvalid;
    
    // Internal address registers
    logic [ADDR_WIDTH-1:0] axi_awaddr;
    logic [ADDR_WIDTH-1:0] axi_araddr;
    
    // AXI4-Lite Write Address Channel
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready <= 1'b0;
            axi_awaddr <= '0;
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
    always_ff @(posedge aclk) begin
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
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                gpio_data_reg[i] <= '0;
                gpio_dir_reg[i] <= '0;  // Default to all inputs
            end
        end else begin
            if (axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid) begin
                case (axi_awaddr[3:2])
                    2'b00: begin  // Channel 0 Data Register
                        if (s_axi_wstrb[0]) gpio_data_reg[0][7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1] && GPIO_WIDTH > 8) gpio_data_reg[0][15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2] && GPIO_WIDTH > 16) gpio_data_reg[0][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3] && GPIO_WIDTH > 24) gpio_data_reg[0][31:24] <= s_axi_wdata[31:24];
                    end
                    2'b01: begin  // Channel 0 Direction Register
                        if (s_axi_wstrb[0]) gpio_dir_reg[0][7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1] && GPIO_WIDTH > 8) gpio_dir_reg[0][15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2] && GPIO_WIDTH > 16) gpio_dir_reg[0][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3] && GPIO_WIDTH > 24) gpio_dir_reg[0][31:24] <= s_axi_wdata[31:24];
                    end
                    2'b10: begin  // Channel 1 Data Register
                        if (NUM_CHANNELS > 1) begin
                            if (s_axi_wstrb[0]) gpio_data_reg[1][7:0] <= s_axi_wdata[7:0];
                            if (s_axi_wstrb[1] && GPIO_WIDTH > 8) gpio_data_reg[1][15:8] <= s_axi_wdata[15:8];
                            if (s_axi_wstrb[2] && GPIO_WIDTH > 16) gpio_data_reg[1][23:16] <= s_axi_wdata[23:16];
                            if (s_axi_wstrb[3] && GPIO_WIDTH > 24) gpio_data_reg[1][31:24] <= s_axi_wdata[31:24];
                        end
                    end
                    2'b11: begin  // Channel 1 Direction Register
                        if (NUM_CHANNELS > 1) begin
                            if (s_axi_wstrb[0]) gpio_dir_reg[1][7:0] <= s_axi_wdata[7:0];
                            if (s_axi_wstrb[1] && GPIO_WIDTH > 8) gpio_dir_reg[1][15:8] <= s_axi_wdata[15:8];
                            if (s_axi_wstrb[2] && GPIO_WIDTH > 16) gpio_dir_reg[1][23:16] <= s_axi_wdata[23:16];
                            if (s_axi_wstrb[3] && GPIO_WIDTH > 24) gpio_dir_reg[1][31:24] <= s_axi_wdata[31:24];
                        end
                    end
                endcase
            end
        end
    end
    
    // AXI4-Lite Write Response Channel
    always_ff @(posedge aclk) begin
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
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axi_arready <= 1'b0;
            axi_araddr <= '0;
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
    always_ff @(posedge aclk) begin
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
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            axi_rdata <= '0;
        end else begin
            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                case (axi_araddr[3:2])
                    2'b00: begin  // Channel 0 Data Register
                        axi_rdata <= '0;
                        // For inputs, read from gpio_i; for outputs, read from gpio_data_reg
                        for (int i = 0; i < GPIO_WIDTH; i++) begin
                            axi_rdata[i] <= gpio_dir_reg[0][i] ? gpio_data_reg[0][i] : gpio_i[0][i];
                        end
                    end
                    2'b01: begin  // Channel 0 Direction Register
                        axi_rdata <= '0;
                        axi_rdata[GPIO_WIDTH-1:0] <= gpio_dir_reg[0];
                    end
                    2'b10: begin  // Channel 1 Data Register
                        axi_rdata <= '0;
                        if (NUM_CHANNELS > 1) begin
                            for (int i = 0; i < GPIO_WIDTH; i++) begin
                                axi_rdata[i] <= gpio_dir_reg[1][i] ? gpio_data_reg[1][i] : gpio_i[1][i];
                            end
                        end
                    end
                    2'b11: begin  // Channel 1 Direction Register
                        axi_rdata <= '0;
                        if (NUM_CHANNELS > 1) begin
                            axi_rdata[GPIO_WIDTH-1:0] <= gpio_dir_reg[1];
                        end
                    end
                endcase
            end
        end
    end
    
    // GPIO output assignments
    generate
        for (genvar ch = 0; ch < NUM_CHANNELS; ch++) begin : gen_gpio_channels
            assign gpio_o[ch] = gpio_data_reg[ch];
            assign gpio_t[ch] = ~gpio_dir_reg[ch];  // Invert: 1=input (tristate), 0=output
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