/*
 * AXI4-Lite UART Controller
 * 
 * This module implements a UART controller with AXI4-Lite slave interface.
 * Features:
 * - Configurable baud rate and clock frequency
 * - Standard UART protocol (8N1 default, configurable)
 * - TX/RX with FIFO buffers
 * - Interrupt support for various events
 * - AXI4-Lite compliant slave interface
 * 
 * Register Map:
 * 0x00: Control Register (R/W) - UART enable, format control
 * 0x04: Status Register (R) - TX/RX status, errors
 * 0x08: Baud Rate Divisor (R/W) - Clock divisor for baud rate
 * 0x0C: TX Data Register (W) - Transmit data
 * 0x10: RX Data Register (R) - Receive data
 * 0x14: Interrupt Enable (R/W) - Interrupt enable bits
 * 0x18: Interrupt Status (R/W1C) - Interrupt status bits
 */

module axi_lite_uart #(
    parameter ADDR_WIDTH = 5,           // AXI address width (minimum 5 for register map)
    parameter CLK_FREQ = 100000000,     // Input clock frequency in Hz
    parameter DEFAULT_BAUD = 115200,    // Default baud rate
    parameter FIFO_DEPTH = 16           // TX/RX FIFO depth (power of 2)
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
    
    // UART Interface
    output                          uart_txd,   // UART transmit data
    input                           uart_rxd,   // UART receive data
    
    // Interrupt
    output                          interrupt   // Interrupt output
);

    // Parameter validation
    initial begin
        if (ADDR_WIDTH < 5) begin
            $error("ADDR_WIDTH must be at least 5 for register map, got %0d", ADDR_WIDTH);
        end
        if (CLK_FREQ < 1000000) begin
            $error("CLK_FREQ must be at least 1MHz, got %0d", CLK_FREQ);
        end
        if (DEFAULT_BAUD < 300 || DEFAULT_BAUD > 3000000) begin
            $error("DEFAULT_BAUD must be between 300 and 3M, got %0d", DEFAULT_BAUD);
        end
        if (FIFO_DEPTH < 4 || (FIFO_DEPTH & (FIFO_DEPTH-1)) != 0) begin
            $error("FIFO_DEPTH must be a power of 2 and >= 4, got %0d", FIFO_DEPTH);
        end
    end

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
    localparam CTRL_STOP_BITS   = 5;  // 0=1 stop bit, 1=2 stop bits
    
    // Status register bits
    localparam STAT_TX_EMPTY    = 0;
    localparam STAT_TX_FULL     = 1;
    localparam STAT_RX_EMPTY    = 2;
    localparam STAT_RX_FULL     = 3;
    localparam STAT_FRAME_ERR   = 4;
    localparam STAT_PARITY_ERR  = 5;
    localparam STAT_OVERRUN_ERR = 6;
    
    // Interrupt bits (same as status for simplicity)
    localparam INT_TX_EMPTY     = 0;
    localparam INT_TX_FULL      = 1;
    localparam INT_RX_EMPTY     = 2;
    localparam INT_RX_FULL      = 3;
    localparam INT_FRAME_ERR    = 4;
    localparam INT_PARITY_ERR   = 5;
    localparam INT_OVERRUN_ERR  = 6;

    // Internal registers
    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [31:0] baud_div_reg;
    reg [31:0] int_enable_reg;
    reg [31:0] int_status_reg;
    
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

    // AXI4-Lite assignments
    assign s_axi_awready = axi_awready;
    assign s_axi_wready = axi_wready;
    assign s_axi_bresp = axi_bresp;
    assign s_axi_bvalid = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata = axi_rdata;
    assign s_axi_rresp = axi_rresp;
    assign s_axi_rvalid = axi_rvalid;

    // Calculate default baud rate divisor
    localparam DEFAULT_BAUD_DIV = CLK_FREQ / (DEFAULT_BAUD * 16);

    // UART signals
    reg baud_tick;
    reg [15:0] baud_counter;
    
    // TX FIFO
    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] tx_wr_ptr, tx_rd_ptr;
    wire tx_fifo_empty = (tx_wr_ptr == tx_rd_ptr);
    wire tx_fifo_full = (tx_wr_ptr == {~tx_rd_ptr[$clog2(FIFO_DEPTH)], tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]});
    wire [$clog2(FIFO_DEPTH):0] tx_fifo_count = tx_wr_ptr - tx_rd_ptr;
    
    // RX FIFO
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] rx_wr_ptr, rx_rd_ptr;
    wire rx_fifo_empty = (rx_wr_ptr == rx_rd_ptr);
    wire rx_fifo_full = (rx_wr_ptr == {~rx_rd_ptr[$clog2(FIFO_DEPTH)], rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]});
    wire [$clog2(FIFO_DEPTH):0] rx_fifo_count = rx_wr_ptr - rx_rd_ptr;
    
    // TX state machine
    reg [3:0] tx_state;
    reg [3:0] tx_bit_counter;
    reg [7:0] tx_shift_reg;
    reg [3:0] tx_baud_counter;
    reg tx_parity_bit;
    reg uart_txd_reg;
    
    localparam TX_IDLE      = 4'h0;
    localparam TX_START     = 4'h1;
    localparam TX_DATA      = 4'h2;
    localparam TX_PARITY    = 4'h3;
    localparam TX_STOP1     = 4'h4;
    localparam TX_STOP2     = 4'h5;
    
    // RX state machine
    reg [3:0] rx_state;
    reg [3:0] rx_bit_counter;
    reg [7:0] rx_shift_reg;
    reg [3:0] rx_baud_counter;
    reg rx_parity_bit;
    reg uart_rxd_sync;
    reg uart_rxd_prev;
    
    localparam RX_IDLE      = 4'h0;
    localparam RX_START     = 4'h1;
    localparam RX_DATA      = 4'h2;
    localparam RX_PARITY    = 4'h3;
    localparam RX_STOP      = 4'h4;

    assign uart_txd = uart_txd_reg;

    // Initialize all registers properly
    initial begin
        tx_wr_ptr = 0;
        tx_rd_ptr = 0;
        rx_wr_ptr = 0;
        rx_rd_ptr = 0;
        tx_state = TX_IDLE;
        rx_state = RX_IDLE;
        uart_txd_reg = 1'b1;
    end

    // Baud rate generator
    always @(posedge aclk) begin
        if (!aresetn) begin
            baud_counter <= 16'h0000;
            baud_tick <= 1'b0;
        end else begin
            if (baud_counter >= baud_div_reg[15:0] - 1) begin
                baud_counter <= 16'h0000;
                baud_tick <= 1'b1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick <= 1'b0;
            end
        end
    end

    // RX synchronizer
    always @(posedge aclk) begin
        if (!aresetn) begin
            uart_rxd_sync <= 1'b1;
            uart_rxd_prev <= 1'b1;
        end else begin
            uart_rxd_sync <= uart_rxd;
            uart_rxd_prev <= uart_rxd_sync;
        end
    end

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
            baud_div_reg <= DEFAULT_BAUD_DIV;
            int_enable_reg <= 32'h00000000;
        end else begin
            if (aw_data_valid && ~axi_bvalid) begin
                case (axi_awaddr[4:2])
                    CTRL_REG[4:2]: begin
                        if (s_axi_wstrb[0]) ctrl_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) ctrl_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) ctrl_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) ctrl_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    BAUD_REG[4:2]: begin
                        if (s_axi_wstrb[0]) baud_div_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) baud_div_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) baud_div_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) baud_div_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    TX_DATA_REG[4:2]: begin
                        // Write to TX FIFO
                        if (s_axi_wstrb[0] && !tx_fifo_full && ctrl_reg[CTRL_ENABLE] && ctrl_reg[CTRL_TX_EN]) begin
                            tx_fifo[tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= s_axi_wdata[7:0];
                            tx_wr_ptr <= tx_wr_ptr + 1;
                        end
                    end
                    INT_EN_REG[4:2]: begin
                        if (s_axi_wstrb[0]) int_enable_reg[7:0] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) int_enable_reg[15:8] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) int_enable_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) int_enable_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    INT_STAT_REG[4:2]: begin
                        // W1C - Write 1 to clear
                        if (s_axi_wstrb[0]) int_status_reg[7:0] <= int_status_reg[7:0] & ~s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) int_status_reg[15:8] <= int_status_reg[15:8] & ~s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) int_status_reg[23:16] <= int_status_reg[23:16] & ~s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) int_status_reg[31:24] <= int_status_reg[31:24] & ~s_axi_wdata[31:24];
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
                    CTRL_REG[4:2]: begin
                        axi_rdata <= ctrl_reg;
                    end
                    STATUS_REG[4:2]: begin
                        axi_rdata <= status_reg;
                    end
                    BAUD_REG[4:2]: begin
                        axi_rdata <= baud_div_reg;
                    end
                    RX_DATA_REG[4:2]: begin
                        if (!rx_fifo_empty && ctrl_reg[CTRL_ENABLE] && ctrl_reg[CTRL_RX_EN]) begin
                            axi_rdata <= {24'h000000, rx_fifo[rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]]};
                            rx_rd_ptr <= rx_rd_ptr + 1;
                        end else begin
                            axi_rdata <= 32'h00000000;
                        end
                    end
                    INT_EN_REG[4:2]: begin
                        axi_rdata <= int_enable_reg;
                    end
                    INT_STAT_REG[4:2]: begin
                        axi_rdata <= int_status_reg;
                    end
                    default: begin
                        axi_rdata <= 32'h00000000;
                    end
                endcase
            end
        end
    end

    // Status register management (centralized)
    reg rx_frame_error, rx_parity_error, rx_overrun_error;
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            status_reg <= 32'h00000005; // TX empty + RX empty initially
        end else begin
            // FIFO status bits
            status_reg[STAT_TX_EMPTY] <= tx_fifo_empty;
            status_reg[STAT_TX_FULL] <= tx_fifo_full;
            status_reg[STAT_RX_EMPTY] <= rx_fifo_empty;
            status_reg[STAT_RX_FULL] <= rx_fifo_full;
            
            // Error flags (sticky - set when error occurs)
            if (rx_frame_error) status_reg[STAT_FRAME_ERR] <= 1'b1;
            if (rx_parity_error) status_reg[STAT_PARITY_ERR] <= 1'b1;
            if (rx_overrun_error) status_reg[STAT_OVERRUN_ERR] <= 1'b1;
        end
    end

    // TX state machine
    always @(posedge aclk) begin
        if (!aresetn) begin
            tx_state <= TX_IDLE;
            tx_bit_counter <= 4'h0;
            tx_shift_reg <= 8'h00;
            tx_baud_counter <= 4'h0;
            tx_parity_bit <= 1'b0;
            uart_txd_reg <= 1'b1;
            tx_rd_ptr <= 0;
        end else begin
            if (ctrl_reg[CTRL_ENABLE] && ctrl_reg[CTRL_TX_EN]) begin
                case (tx_state)
                    TX_IDLE: begin
                        uart_txd_reg <= 1'b1;
                        if (!tx_fifo_empty) begin
                            tx_shift_reg <= tx_fifo[tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
                            tx_rd_ptr <= tx_rd_ptr + 1;
                            tx_state <= TX_START;
                            tx_baud_counter <= 4'h0;
                            tx_parity_bit <= ctrl_reg[CTRL_PARITY_ODD] ? 1'b1 : 1'b0;
                        end
                    end
                    TX_START: begin
                        uart_txd_reg <= 1'b0; // Start bit
                        if (baud_tick) begin
                            if (tx_baud_counter >= 4'd15) begin
                                tx_state <= TX_DATA;
                                tx_bit_counter <= 4'h0;
                                tx_baud_counter <= 4'h0;
                            end else begin
                                tx_baud_counter <= tx_baud_counter + 1;
                            end
                        end
                    end
                    TX_DATA: begin
                        uart_txd_reg <= tx_shift_reg[0];
                        if (baud_tick) begin
                            if (tx_baud_counter >= 4'd15) begin
                                tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                                tx_parity_bit <= tx_parity_bit ^ tx_shift_reg[0];
                                tx_baud_counter <= 4'h0;
                                if (tx_bit_counter >= 4'd7) begin
                                    if (ctrl_reg[CTRL_PARITY_EN]) begin
                                        tx_state <= TX_PARITY;
                                    end else begin
                                        tx_state <= TX_STOP1;
                                    end
                                    tx_bit_counter <= 4'h0;
                                end else begin
                                    tx_bit_counter <= tx_bit_counter + 1;
                                end
                            end else begin
                                tx_baud_counter <= tx_baud_counter + 1;
                            end
                        end
                    end
                    TX_PARITY: begin
                        uart_txd_reg <= tx_parity_bit;
                        if (baud_tick) begin
                            if (tx_baud_counter >= 4'd15) begin
                                tx_state <= TX_STOP1;
                                tx_baud_counter <= 4'h0;
                            end else begin
                                tx_baud_counter <= tx_baud_counter + 1;
                            end
                        end
                    end
                    TX_STOP1: begin
                        uart_txd_reg <= 1'b1; // Stop bit
                        if (baud_tick) begin
                            if (tx_baud_counter >= 4'd15) begin
                                if (ctrl_reg[CTRL_STOP_BITS]) begin
                                    tx_state <= TX_STOP2;
                                end else begin
                                    tx_state <= TX_IDLE;
                                end
                                tx_baud_counter <= 4'h0;
                            end else begin
                                tx_baud_counter <= tx_baud_counter + 1;
                            end
                        end
                    end
                    TX_STOP2: begin
                        uart_txd_reg <= 1'b1; // Second stop bit
                        if (baud_tick) begin
                            if (tx_baud_counter >= 4'd15) begin
                                tx_state <= TX_IDLE;
                                tx_baud_counter <= 4'h0;
                            end else begin
                                tx_baud_counter <= tx_baud_counter + 1;
                            end
                        end
                    end
                endcase
            end else begin
                tx_state <= TX_IDLE;
                uart_txd_reg <= 1'b1;
            end
        end
    end

    // RX state machine and error flags management
    always @(posedge aclk) begin
        if (!aresetn) begin
            rx_state <= RX_IDLE;
            rx_bit_counter <= 4'h0;
            rx_shift_reg <= 8'h00;
            rx_baud_counter <= 4'h0;
            rx_parity_bit <= 1'b0;
            rx_wr_ptr <= 0;
            rx_frame_error <= 1'b0;
            rx_parity_error <= 1'b0;
            rx_overrun_error <= 1'b0;
        end else begin
            // Clear error flags by default
            rx_frame_error <= 1'b0;
            rx_parity_error <= 1'b0;
            rx_overrun_error <= 1'b0;
            if (ctrl_reg[CTRL_ENABLE] && ctrl_reg[CTRL_RX_EN]) begin
                case (rx_state)
                    RX_IDLE: begin
                        if (uart_rxd_prev && !uart_rxd_sync) begin // Start bit detected
                            rx_state <= RX_START;
                            rx_baud_counter <= 4'h0;
                            rx_parity_bit <= ctrl_reg[CTRL_PARITY_ODD] ? 1'b1 : 1'b0;
                        end
                    end
                    RX_START: begin
                        if (baud_tick) begin
                            if (rx_baud_counter >= 4'd7) begin // Sample at middle of bit
                                if (uart_rxd_sync == 1'b0) begin // Valid start bit
                                    rx_state <= RX_DATA;
                                    rx_bit_counter <= 4'h0;
                                    rx_baud_counter <= 4'h0;
                                end else begin
                                    rx_state <= RX_IDLE; // False start
                                end
                            end else begin
                                rx_baud_counter <= rx_baud_counter + 1;
                            end
                        end
                    end
                    RX_DATA: begin
                        if (baud_tick) begin
                            if (rx_baud_counter >= 4'd15) begin
                                rx_shift_reg <= {uart_rxd_sync, rx_shift_reg[7:1]};
                                rx_parity_bit <= rx_parity_bit ^ uart_rxd_sync;
                                rx_baud_counter <= 4'h0;
                                if (rx_bit_counter >= 4'd7) begin
                                    if (ctrl_reg[CTRL_PARITY_EN]) begin
                                        rx_state <= RX_PARITY;
                                    end else begin
                                        rx_state <= RX_STOP;
                                    end
                                    rx_bit_counter <= 4'h0;
                                end else begin
                                    rx_bit_counter <= rx_bit_counter + 1;
                                end
                            end else begin
                                rx_baud_counter <= rx_baud_counter + 1;
                            end
                        end
                    end
                    RX_PARITY: begin
                        if (baud_tick) begin
                            if (rx_baud_counter >= 4'd15) begin
                                if ((rx_parity_bit ^ uart_rxd_sync) != 1'b0) begin
                                    rx_parity_error <= 1'b1; // Parity error
                                end
                                rx_state <= RX_STOP;
                                rx_baud_counter <= 4'h0;
                            end else begin
                                rx_baud_counter <= rx_baud_counter + 1;
                            end
                        end
                    end
                    RX_STOP: begin
                        if (baud_tick) begin
                            if (rx_baud_counter >= 4'd15) begin
                                if (uart_rxd_sync == 1'b1) begin // Valid stop bit
                                    if (!rx_fifo_full) begin
                                        rx_fifo[rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= rx_shift_reg;
                                        rx_wr_ptr <= rx_wr_ptr + 1;
                                    end else begin
                                        rx_overrun_error <= 1'b1; // Overrun error
                                    end
                                end else begin
                                    rx_frame_error <= 1'b1; // Frame error
                                end
                                rx_state <= RX_IDLE;
                                rx_baud_counter <= 4'h0;
                            end else begin
                                rx_baud_counter <= rx_baud_counter + 1;
                            end
                        end
                    end
                endcase
            end else begin
                rx_state <= RX_IDLE;
            end
        end
    end

    // Interrupt status register management
    always @(posedge aclk) begin
        if (!aresetn) begin
            int_status_reg <= 32'h00000000;
        end else begin
            // Set interrupt status based on FIFO status changes
            if (tx_fifo_empty && !int_status_reg[INT_TX_EMPTY]) begin
                int_status_reg[INT_TX_EMPTY] <= 1'b1;
            end
            if (tx_fifo_full && !int_status_reg[INT_TX_FULL]) begin
                int_status_reg[INT_TX_FULL] <= 1'b1;
            end
            if (!rx_fifo_empty && int_status_reg[INT_RX_EMPTY]) begin
                int_status_reg[INT_RX_EMPTY] <= 1'b0;
            end
            if (rx_fifo_full && !int_status_reg[INT_RX_FULL]) begin
                int_status_reg[INT_RX_FULL] <= 1'b1;
            end
            
            // Set error interrupt flags based on status register
            if (status_reg[STAT_FRAME_ERR] && !int_status_reg[INT_FRAME_ERR]) begin
                int_status_reg[INT_FRAME_ERR] <= 1'b1;
            end
            if (status_reg[STAT_PARITY_ERR] && !int_status_reg[INT_PARITY_ERR]) begin
                int_status_reg[INT_PARITY_ERR] <= 1'b1;
            end
            if (status_reg[STAT_OVERRUN_ERR] && !int_status_reg[INT_OVERRUN_ERR]) begin
                int_status_reg[INT_OVERRUN_ERR] <= 1'b1;
            end
        end
    end

    // Interrupt output
    assign interrupt = |(int_status_reg & int_enable_reg);

endmodule