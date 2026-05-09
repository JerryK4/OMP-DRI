`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=   Module: omp_hardware_accelerator_v1_0                                           =
=   Description: AXI4 Wrapper for OMP Core. Integrates AXI-Lite for control,        =
=                AXI-Stream for high-speed data Y/PHI, and Master AXI-Stream        =
=                for result streaming (X_hat + Lambda).                             =
=                                                                                   =
=====================================================================================
*/

module omp_hardware_accelerator_v1_0 #
(
    // ==============================================================
    // 1. OMP CORE PARAMETERS (16x16)
    // ==============================================================
    parameter integer NUM_MAC    = 4,
    parameter integer DW         = 24,
    parameter integer NUM_K      = 16,
    parameter integer ADDR_W_PHI = 12, // 4096 addresses
    parameter integer ADDR_W_Y   = 4,
    parameter integer ADDR_W_R   = 8, 
    parameter integer ROW_W      = 6,
    parameter integer COL_W      = 8,
    parameter integer ADDR_W_Q   = 8,
    parameter integer DOT_W      = 56,
    parameter integer MAX_I      = 16,
    parameter integer HIST_W     = 9,

    // ==============================================================
    // 2. AXI4 INTERFACE PARAMETERS
    // ==============================================================
    parameter integer C_S_AXI_CTRL_DATA_WIDTH = 32,
    parameter integer C_S_AXI_CTRL_ADDR_WIDTH = 6, // 16 registers (64 Bytes)
    parameter integer C_AXIS_TDATA_WIDTH      = 32
)
(
    // --- Clock and Reset ---
    input  wire                                     aclk,
    input  wire                                     aresetn,

    // --- 1. AXI4-LITE SLAVE (Control & Config) ---
    input  wire [C_S_AXI_CTRL_ADDR_WIDTH-1:0]       s_axi_ctrl_awaddr,
    input  wire [2:0]                               s_axi_ctrl_awprot,
    input  wire                                     s_axi_ctrl_awvalid,
    output wire                                     s_axi_ctrl_awready,
    input  wire [C_S_AXI_CTRL_DATA_WIDTH-1:0]       s_axi_ctrl_wdata,
    input  wire [(C_S_AXI_CTRL_DATA_WIDTH/8)-1:0]   s_axi_ctrl_wstrb,
    input  wire                                     s_axi_ctrl_wvalid,
    output wire                                     s_axi_ctrl_wready,
    output wire [1:0]                               s_axi_ctrl_bresp,
    output wire                                     s_axi_ctrl_bvalid,
    input  wire                                     s_axi_ctrl_bready,
    input  wire [C_S_AXI_CTRL_ADDR_WIDTH-1:0]       s_axi_ctrl_araddr,
    input  wire [2:0]                               s_axi_ctrl_arprot,
    input  wire                                     s_axi_ctrl_arvalid,
    output wire                                     s_axi_ctrl_arready,
    output wire [C_S_AXI_CTRL_DATA_WIDTH-1:0]       s_axi_ctrl_rdata,
    output wire [1:0]                               s_axi_ctrl_rresp,
    output wire                                     s_axi_ctrl_rvalid,
    input  wire                                     s_axi_ctrl_rready,

    // --- 2. AXI4-STREAM SLAVE (Input Vector Y) ---
    input  wire [C_AXIS_TDATA_WIDTH-1:0]            s_axis_y_tdata,
    input  wire [(C_AXIS_TDATA_WIDTH/8)-1:0]        s_axis_y_tstrb,
    input  wire                                     s_axis_y_tlast,
    input  wire                                     s_axis_y_tvalid,
    output wire                                     s_axis_y_tready,

    // --- 3. AXI4-STREAM SLAVE (Input Matrix PHI) ---
    input  wire [C_AXIS_TDATA_WIDTH-1:0]            s_axis_phi_tdata,
    input  wire [(C_AXIS_TDATA_WIDTH/8)-1:0]        s_axis_phi_tstrb,
    input  wire                                     s_axis_phi_tlast,
    input  wire                                     s_axis_phi_tvalid,
    output wire                                     s_axis_phi_tready,

    // --- 4. AXI4-STREAM MASTER (Output X_hat Stream) ---
    output wire                                     m_axis_x_tvalid,
    output wire [C_AXIS_TDATA_WIDTH-1:0]            m_axis_x_tdata,
    output wire [(C_AXIS_TDATA_WIDTH/8)-1:0]        m_axis_x_tstrb,
    output wire                                     m_axis_x_tlast,
    input  wire                                     m_axis_x_tready
);

//--------------------------------------------------------------------------------------------------------------
// [A] AXI4-LITE SLAVE LOGIC (Standard Implementation)
//--------------------------------------------------------------------------------------------------------------
    reg [31:0] slv_reg [0:15];
    reg        axi_awready;
    reg        axi_wready;
    reg        axi_bvalid;
    reg        axi_arready;
    reg        axi_rvalid;
    reg [31:0] axi_rdata;
    
    wire       slv_reg_wren;
    wire       system_done;
    integer    i;

    assign s_axi_ctrl_awready = axi_awready;
    assign s_axi_ctrl_wready  = axi_wready;
    assign s_axi_ctrl_bresp   = 2'b00; 
    assign s_axi_ctrl_bvalid  = axi_bvalid;
    assign s_axi_ctrl_arready = axi_arready;
    assign s_axi_ctrl_rdata   = axi_rdata;
    assign s_axi_ctrl_rresp   = 2'b00; 
    assign s_axi_ctrl_rvalid  = axi_rvalid;

    // --- Write Channel ---
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
        end else begin
            if (~axi_awready && s_axi_ctrl_awvalid && s_axi_ctrl_wvalid)
                axi_awready <= 1'b1;
            else
                axi_awready <= 1'b0;

            if (~axi_wready && s_axi_ctrl_wvalid && s_axi_ctrl_awvalid)
                axi_wready <= 1'b1;
            else
                axi_wready <= 1'b0;

            if (axi_awready && s_axi_ctrl_awvalid && axi_wready && s_axi_ctrl_wvalid && ~axi_bvalid)
                axi_bvalid <= 1'b1;
            else if (s_axi_ctrl_bready && axi_bvalid)
                axi_bvalid <= 1'b0;
        end
    end

    assign slv_reg_wren = axi_wready && s_axi_ctrl_wvalid && axi_awready && s_axi_ctrl_awvalid;
    wire [3:0] reg_waddr = s_axi_ctrl_awaddr[5:2];

    always @(posedge aclk) begin
        if (!aresetn) begin
            for (i = 0; i < 16; i = i + 1) slv_reg[i] <= 0;
        end else begin
            if (slv_reg_wren) begin
                slv_reg[reg_waddr] <= s_axi_ctrl_wdata;
            end 
            else begin
                // Auto-clear bit Start[0] and bit Reset_Ptr[1] to avoid race conditions
                if (slv_reg[0][0]) slv_reg[0][0] <= 1'b0; 
                if (slv_reg[0][1]) slv_reg[0][1] <= 1'b0;
            end
        end
    end

    // --- Read Channel ---
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= 0;
        end else begin
            if (~axi_arready && s_axi_ctrl_arvalid)
                axi_arready <= 1'b1;
            else
                axi_arready <= 1'b0;

            if (axi_arready && s_axi_ctrl_arvalid && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                case (s_axi_ctrl_araddr[5:2])
                    4'h4:    axi_rdata <= {31'd0, system_done}; // Reg 4: Status Done
                    default: axi_rdata <= slv_reg[s_axi_ctrl_araddr[5:2]];
                endcase
            end else if (axi_rvalid && s_axi_ctrl_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

//--------------------------------------------------------------------------------------------------------------
// [B] DATA ADAPTER: 4x32-bit Packets -> 1x96-bit (For BRAM Loading)
//--------------------------------------------------------------------------------------------------------------
    // --- Adapter for Vector Y ---
    reg [1:0]           y_step; 
    reg [95:0]          y_hold; 
    reg [ADDR_W_Y-1:0]  y_wa; 
    reg                 y_we_int;
    
    assign s_axis_y_tready = aresetn; 
    
    always @(posedge aclk) begin
        if (!aresetn || slv_reg[0][1]) begin 
            y_step <= 0; y_wa <= 0; y_we_int <= 0; y_hold <= 0; 
        end else begin
            y_we_int <= 1'b0; 
            if (s_axis_y_tvalid && s_axis_y_tready) begin
                case(y_step)
                    2'd0: begin y_hold[23:0]  <= s_axis_y_tdata[23:0]; y_step <= 2'd1; end
                    2'd1: begin y_hold[47:24] <= s_axis_y_tdata[23:0]; y_step <= 2'd2; end
                    2'd2: begin y_hold[71:48] <= s_axis_y_tdata[23:0]; y_step <= 2'd3; end
                    2'd3: begin 
                        y_hold[95:72] <= s_axis_y_tdata[23:0]; 
                        y_step <= 2'd0; 
                        y_we_int <= 1'b1; 
                    end
                endcase
            end
            if (y_we_int) y_wa <= y_wa + 1'b1;
        end
    end

    // --- Adapter for Matrix PHI ---
    reg [1:0]           p_step; 
    reg [95:0]          p_hold; 
    reg [ADDR_W_PHI-1:0] p_wa; 
    reg                 p_we_int;
    
    assign s_axis_phi_tready = aresetn;
    
    always @(posedge aclk) begin
        if (!aresetn || slv_reg[0][1]) begin 
            p_step <= 0; p_wa <= 0; p_we_int <= 0; p_hold <= 0; 
        end else begin
            p_we_int <= 1'b0;
            if (s_axis_phi_tvalid && s_axis_phi_tready) begin
                case(p_step)
                    2'd0: begin p_hold[23:0]  <= s_axis_phi_tdata[23:0]; p_step <= 2'd1; end
                    2'd1: begin p_hold[47:24] <= s_axis_phi_tdata[23:0]; p_step <= 2'd2; end
                    2'd2: begin p_hold[71:48] <= s_axis_phi_tdata[23:0]; p_step <= 2'd3; end
                    2'd3: begin 
                        p_hold[95:72] <= s_axis_phi_tdata[23:0]; 
                        p_step <= 2'd0; 
                        p_we_int <= 1'b1; 
                    end
                endcase
            end
            if (p_we_int) p_wa <= p_wa + 1'b1;
        end
    end

//--------------------------------------------------------------------------------------------------------------
// [C] OMP CORE SYSTEM INSTANTIATION
//--------------------------------------------------------------------------------------------------------------
    wire [DW-1:0]           w_x_hat_val;
    wire [$clog2(NUM_K)-1:0] w_x_hat_idx;
    wire                    w_x_hat_vld;
    wire [MAX_I*COL_W-1:0]  w_lambda_arr;

    omp_system_top #(
        .DW(DW), .NUM_K(NUM_K), .ADDR_W_PHI(ADDR_W_PHI), .ADDR_W_Y(ADDR_W_Y), 
        .ADDR_W_R(ADDR_W_R), .ROW_W(ROW_W), .COL_W(COL_W), .ADDR_W_Q(ADDR_W_Q), 
        .DOT_W(DOT_W), .MAX_I(MAX_I), .HIST_W(HIST_W), .NUM_MAC(NUM_MAC)
    ) dut_core (
        .clk              (aclk),
        .rst_n            (aresetn),
        .start_system     (slv_reg[0][0]),
        
        .N_cols           (slv_reg[1][COL_W-1:0]),
        .M_rows           (slv_reg[2][ROW_W-1:0]),
        .K_sparsity       (slv_reg[3][$clog2(NUM_K):0]),

        .y_we_cpu         (y_we_int),
        .y_addr_cpu       (y_wa),
        .y_din_cpu        (y_hold),

        .phi_we_cpu       (p_we_int),
        .phi_addr_cpu     (p_wa),
        .phi_din_cpu      (p_hold),

        .x_hat_val        (w_x_hat_val),
        .x_hat_idx        (w_x_hat_idx),
        .x_hat_valid      (w_x_hat_vld),
        .system_done      (system_done),
        .lambda_array_out (w_lambda_arr)
    );
    
    // Extract Lambda Coordinate based on current stream Index
    wire [COL_W-1:0] current_pixel_lambda;
    assign current_pixel_lambda = w_lambda_arr[w_x_hat_idx * COL_W +: COL_W];

//--------------------------------------------------------------------------------------------------------------
// [D] MASTER STREAM: RESULT OUTPUT (X_HAT + LAMBDA)
//--------------------------------------------------------------------------------------------------------------
    // Packet Format: [31:24] Lambda (8-bit) | [23:0] X_hat Value (24-bit)
    localparam PADDING_W = 32 - (DW + COL_W);
    assign m_axis_x_tdata  = { {PADDING_W{1'b0}}, current_pixel_lambda, w_x_hat_val };
    
    assign m_axis_x_tvalid = w_x_hat_vld;
    assign m_axis_x_tstrb  = 4'hF; 
    
    // T_LAST Logic: Trigger when current Index reaches (K_sparsity - 1)
    wire [$clog2(NUM_K)-1:0] target_k_minus_1 = slv_reg[3][$clog2(NUM_K)-1:0] - 1'b1;
    assign m_axis_x_tlast  = (w_x_hat_idx == target_k_minus_1) && w_x_hat_vld;

endmodule