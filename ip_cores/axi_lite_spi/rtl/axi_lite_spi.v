/*
 * AXI4-Lite SPI Controller
 * 
 * This module implements a simple SPI controller with AXI4-Lite slave interface.
 * Features:
 * - Configurable SPI modes (CPOL/CPHA)
 * - Configurable data width (8, 16, or 32 bits)
 * - Configurable clock divider for SPI clock generation
 * - SPI master interface (SCLK, MOSI, MISO, CS)
 * - TX/RX data registers with basic status
 * - AXI4-Lite compliant slave interface
 * 
 * Register Map:
 * 0x00: Control Register (R/W) - SPI enable, mode control
 * 0x04: Status Register (R) - SPI busy, data ready status
 * 0x08: Clock Divider (R/W) - Clock divisor for SPI clock
 * 0x0C: TX Data Register (R/W) - Transmit data
 * 0x10: RX Data Register (R) - Receive data
 * 0x14: Chip Select (R/W) - Chip select control
 */

module axi_lite_spi #(
    parameter ADDR_WIDTH = 5,           // AXI address width (minimum 5 for register map)
    parameter CLK_FREQ = 100000000,     // Input clock frequency in Hz
    parameter DEFAULT_CLKDIV = 100      // Default clock divider for SPI clock
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
    
    // SPI Interface
    output                          spi_clk,    // SPI Clock
    output                          spi_mosi,   // Master Out Slave In
    input                           spi_miso,   // Master In Slave Out  
    output                          spi_cs_n    // Chip Select (active low)
);

    // Parameter validation
    initial begin
        if (ADDR_WIDTH < 5) begin
            $error("ADDR_WIDTH must be at least 5 for register map, got %0d", ADDR_WIDTH);
        end
        if (DEFAULT_CLKDIV < 2) begin
            $error("DEFAULT_CLKDIV must be at least 2, got %0d", DEFAULT_CLKDIV);
        end
    end

    // Register addresses
    localparam CTRL_REG     = 3'b000;  // 0x00
    localparam STATUS_REG   = 3'b001;  // 0x04
    localparam CLKDIV_REG   = 3'b010;  // 0x08
    localparam TXDATA_REG   = 3'b011;  // 0x0C
    localparam RXDATA_REG   = 3'b100;  // 0x10
    localparam CS_REG       = 3'b101;  // 0x14

    // Control Register bits
    localparam CTRL_ENABLE   = 0;  // SPI Enable
    localparam CTRL_CPOL     = 1;  // Clock Polarity
    localparam CTRL_CPHA     = 2;  // Clock Phase
    localparam CTRL_WIDTH    = 4;  // Data Width (2 bits: 00=8, 01=16, 10=32)
    
    // Status Register bits
    localparam STATUS_BUSY   = 0;  // SPI Busy
    localparam STATUS_RXRDY  = 1;  // RX Data Ready

    // Internal registers
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] clkdiv_reg;
    reg [31:0] txdata_reg;
    reg [31:0] rxdata_reg;
    reg [31:0] cs_reg;
    
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
    reg                  ar_addr_valid;  // Track if we have a pending read
    reg                  aw_data_valid;  // Track if we have a pending write

    // SPI Core signals
    reg                  spi_busy;
    reg                  spi_start;
    reg [31:0]           spi_tx_data;
    reg [31:0]           spi_rx_data;
    reg                  spi_rx_ready;
    reg [1:0]            data_width;     // 00=8, 01=16, 10=32 bits
    
    // SPI Clock generation
    reg [31:0]           clk_counter;
    reg                  spi_clk_en;
    reg                  spi_clk_reg;
    
    // SPI State Machine
    reg [2:0]            spi_state;
    reg [5:0]            bit_counter;
    reg [31:0]           shift_reg_tx;
    reg [31:0]           shift_reg_rx;
    
    localparam SPI_IDLE     = 3'b000;
    localparam SPI_START    = 3'b001;
    localparam SPI_CLOCK_H  = 3'b010;
    localparam SPI_CLOCK_L  = 3'b011;
    localparam SPI_FINISH   = 3'b100;

    // Reset values
    initial begin
        ctrl_reg = 32'h00000000;
        status_reg = 32'h00000000;
        clkdiv_reg = DEFAULT_CLKDIV;
        txdata_reg = 32'h00000000;
        rxdata_reg = 32'h00000000;
        cs_reg = 32'h00000001; // CS inactive by default
    end

    //=============================================================================
    // AXI4-Lite Interface Implementation
    //=============================================================================
    
    // AXI4-Lite Write Address Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready <= 1'b0;
            axi_awaddr <= {ADDR_WIDTH{1'b0}};
            aw_data_valid <= 1'b0;
        end else begin
            if (~axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                axi_awready <= 1'b1;
                axi_awaddr <= s_axi_awaddr;
                aw_data_valid <= 1'b1;
            end else begin
                axi_awready <= 1'b0;
                if (axi_bvalid && s_axi_bready) begin
                    aw_data_valid <= 1'b0;
                end
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
    always @(posedge aclk) begin
        if (!aresetn) begin
            ctrl_reg <= 32'h00000000;
            clkdiv_reg <= DEFAULT_CLKDIV;
            txdata_reg <= 32'h00000000;
            cs_reg <= 32'h00000001; // CS inactive by default
        end else begin
            if (aw_data_valid && ~axi_bvalid) begin
                case (axi_awaddr[4:2])
                    CTRL_REG: begin
                        if (s_axi_wstrb[0]) ctrl_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) ctrl_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) ctrl_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) ctrl_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    CLKDIV_REG: begin
                        if (s_axi_wstrb[0]) clkdiv_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) clkdiv_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) clkdiv_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) clkdiv_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    TXDATA_REG: begin
                        if (s_axi_wstrb[0]) txdata_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) txdata_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) txdata_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) txdata_reg[31:24] <= s_axi_wdata[31:24];
                        // Start SPI transaction when TX data is written and SPI is enabled
                        if (ctrl_reg[CTRL_ENABLE] && !spi_busy) begin
                            spi_start <= 1'b1;
                        end
                    end
                    CS_REG: begin
                        if (s_axi_wstrb[0]) cs_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) cs_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) cs_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) cs_reg[31:24] <= s_axi_wdata[31:24];
                    end
                endcase
            end else begin
                spi_start <= 1'b0;
            end
        end
    end
    
    // AXI4-Lite Write Response Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp <= 2'b00;
        end else begin
            if (aw_data_valid && ~axi_bvalid) begin
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
            ar_addr_valid <= 1'b0;
        end else begin
            if (~axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
                axi_araddr <= s_axi_araddr;
                ar_addr_valid <= 1'b1;
            end else begin
                axi_arready <= 1'b0;
                if (axi_rvalid && s_axi_rready) begin
                    ar_addr_valid <= 1'b0;
                end
            end
        end
    end
    
    // AXI4-Lite Read Data Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_rvalid <= 1'b0;
            axi_rresp <= 2'b00;
        end else begin
            if (ar_addr_valid && ~axi_rvalid) begin
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
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_rdata <= 32'h00000000;
        end else begin
            if (ar_addr_valid && ~axi_rvalid) begin
                case (axi_araddr[4:2])
                    CTRL_REG:   axi_rdata <= ctrl_reg;
                    STATUS_REG: axi_rdata <= {30'h0, spi_rx_ready, spi_busy};
                    CLKDIV_REG: axi_rdata <= clkdiv_reg;
                    TXDATA_REG: axi_rdata <= txdata_reg;
                    RXDATA_REG: axi_rdata <= rxdata_reg;
                    CS_REG:     axi_rdata <= cs_reg;
                    default:    axi_rdata <= 32'h00000000;
                endcase
            end
        end
    end

    //=============================================================================
    // SPI Core Implementation
    //=============================================================================
    
    // Extract control signals
    always @(*) begin
        data_width = ctrl_reg[CTRL_WIDTH+1:CTRL_WIDTH];
    end
    
    // SPI Clock generation
    always @(posedge aclk) begin
        if (!aresetn) begin
            clk_counter <= 0;
            spi_clk_en <= 1'b0;
        end else begin
            if (spi_busy) begin
                if (clk_counter >= (clkdiv_reg >> 1) - 1) begin
                    clk_counter <= 0;
                    spi_clk_en <= 1'b1;
                end else begin
                    clk_counter <= clk_counter + 1;
                    spi_clk_en <= 1'b0;
                end
            end else begin
                clk_counter <= 0;
                spi_clk_en <= 1'b0;
            end
        end
    end
    
    // SPI Clock register (for CPOL/CPHA control)
    always @(posedge aclk) begin
        if (!aresetn) begin
            spi_clk_reg <= ctrl_reg[CTRL_CPOL]; // Initialize to CPOL
        end else begin
            if (!spi_busy) begin
                spi_clk_reg <= ctrl_reg[CTRL_CPOL]; // Idle state = CPOL
            end else if (spi_clk_en) begin
                spi_clk_reg <= ~spi_clk_reg;
            end
        end
    end
    
    // SPI State Machine
    always @(posedge aclk) begin
        if (!aresetn) begin
            spi_state <= SPI_IDLE;
            spi_busy <= 1'b0;
            spi_rx_ready <= 1'b0;
            bit_counter <= 0;
            shift_reg_tx <= 0;
            shift_reg_rx <= 0;
        end else begin
            case (spi_state)
                SPI_IDLE: begin
                    spi_busy <= 1'b0;
                    if (spi_start && ctrl_reg[CTRL_ENABLE]) begin
                        spi_state <= SPI_START;
                        spi_busy <= 1'b1;
                        spi_rx_ready <= 1'b0;
                        shift_reg_tx <= txdata_reg;
                        case (data_width)
                            2'b00: bit_counter <= 7;  // 8 bits
                            2'b01: bit_counter <= 15; // 16 bits
                            2'b10: bit_counter <= 31; // 32 bits
                            default: bit_counter <= 7; // Default to 8 bits
                        endcase
                    end
                end
                
                SPI_START: begin
                    if (spi_clk_en) begin
                        if (ctrl_reg[CTRL_CPHA] == 0) begin
                            // CPHA=0: Data changes on leading edge, sampled on trailing edge
                            spi_state <= SPI_CLOCK_H;
                        end else begin
                            // CPHA=1: Data sampled on leading edge, changes on trailing edge
                            spi_state <= SPI_CLOCK_L;
                        end
                    end
                end
                
                SPI_CLOCK_H: begin
                    if (spi_clk_en) begin
                        if (ctrl_reg[CTRL_CPHA] == 0) begin
                            // Sample MISO on trailing edge (falling edge when CPOL=0)
                            shift_reg_rx <= {shift_reg_rx[30:0], spi_miso};
                        end else begin
                            // Change MOSI on trailing edge
                            shift_reg_tx <= {shift_reg_tx[30:0], 1'b0};
                        end
                        
                        if (bit_counter == 0) begin
                            spi_state <= SPI_FINISH;
                        end else begin
                            bit_counter <= bit_counter - 1;
                            spi_state <= SPI_CLOCK_L;
                        end
                    end
                end
                
                SPI_CLOCK_L: begin
                    if (spi_clk_en) begin
                        if (ctrl_reg[CTRL_CPHA] == 0) begin
                            // Change MOSI on leading edge
                            shift_reg_tx <= {shift_reg_tx[30:0], 1'b0};
                        end else begin
                            // Sample MISO on leading edge (rising edge when CPOL=0)
                            shift_reg_rx <= {shift_reg_rx[30:0], spi_miso};
                        end
                        spi_state <= SPI_CLOCK_H;
                    end
                end
                
                SPI_FINISH: begin
                    rxdata_reg <= shift_reg_rx;
                    spi_rx_ready <= 1'b1;
                    spi_state <= SPI_IDLE;
                end
            endcase
        end
    end

    //=============================================================================
    // Output Assignments
    //=============================================================================
    
    // AXI4-Lite outputs
    assign s_axi_awready = axi_awready;
    assign s_axi_wready = axi_wready;
    assign s_axi_bresp = axi_bresp;
    assign s_axi_bvalid = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata = axi_rdata;
    assign s_axi_rresp = axi_rresp;
    assign s_axi_rvalid = axi_rvalid;
    
    // SPI outputs
    assign spi_clk = spi_clk_reg;
    assign spi_mosi = shift_reg_tx[31];  // MSB first
    assign spi_cs_n = cs_reg[0];         // Use LSB of CS register

endmodule