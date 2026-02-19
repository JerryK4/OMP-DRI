`timescale 1ns / 1ps

module qr_mgs_system_top #
(
    parameter DW = 24,         // Q10.13
    parameter ADDR_W_PHI = 12, // 4096 rows
    parameter ADDR_W_Q = 8,    // 256 rows
    parameter DOT_W = 56
)
(
    input wire clk,
    input wire rst_n,
    input wire start_mgs,
    input wire [7:0] lambda_i,   
    input wire [4:0] current_i,  

    // --- Interface Phi BRAM ---
    output wire [ADDR_W_PHI-1:0] phi_addr,
    input  wire [95:0]           phi_data,

    // --- Interface R BRAM ---
    output wire [7:0]            r_addr_a,
    output wire                  r_we_a,
    output wire [23:0]           r_din_a,

    // --- Interface Q BRAM ---
    output wire [ADDR_W_Q-1:0]   q_addr_a,
    output wire                  q_we_a,
    output wire [95:0]           q_din_a,
    output wire [ADDR_W_Q-1:0]   q_addr_b, // Port B dùng chung ??c
    input  wire [95:0]           q_dout_b,

    // --- Interface Residual RAM ---
    output wire [3:0]            res_addr_a, 
    output wire                  res_we_a,
    output wire [95:0]           res_din_a,
    output wire [3:0]            res_addr_b, 
    input  wire [95:0]           res_dout_b,

    output reg                   mgs_done_all
);

    // --- 1. Khai báo tr?ng thái FSM ?i?u ph?i ---
    localparam IDLE         = 3'd0,
               RUN_CORE     = 3'd1, // Ch?y tr?c giao hóa MGS
               WAIT_CORE    = 3'd2,
               RUN_UPDATE   = 3'd3, // Ch?y c?p nh?t Residual
               WAIT_UPDATE  = 3'd4,
               FINISH       = 3'd5;

    reg [2:0] state;
    reg start_core_reg, start_update_reg;
    wire core_done, update_done;

    // --- 2. Tín hi?u trung gian cho Arbitration (?i?u ph?i RAM) ---
    wire [ADDR_W_Q-1:0] q_addr_b_core, q_addr_b_upd;
    wire [ADDR_W_PHI-1:0] phi_addr_core;

    /* ==========================================================
       3. ?I?U PH?I TÀI NGUYÊN (Arbitration Logic)
    ========================================================== */
    // Ch? kh?i Core m?i dùng RAM Phi
    assign phi_addr = phi_addr_core;

    // Port B c?a RAM Q: Core dùng khi tính Rji, Update dùng khi tính Alpha
    assign q_addr_b = (state == RUN_UPDATE || state == WAIT_UPDATE) ? q_addr_b_upd : q_addr_b_core;

    /* ==========================================================
       4. CÀI ??T CÁC MODULE CON
    ========================================================== */
    
    // --- KH?I 1: MGS CORE (Tr?c giao hóa) ---
    qr_mgs_core u_mgs_core (
        .clk(clk), .rst_n(rst_n),
        .start_core(start_core_reg),
        .lambda_i(lambda_i), .current_i(current_i),
        .M_rows_in(4'd15), // M?c ??nh 16x16
        .phi_addr(phi_addr_core), .phi_data(phi_data),
        .r_addr_a(r_addr_a), .r_we_a(r_we_a), .r_din_a(r_din_a),
        .q_addr_a(q_addr_a), .q_we_a(q_we_a), .q_din_a(q_din_a),
        .q_addr_b(q_addr_b_core), .q_dout_b(q_dout_b),
        .core_done(core_done)
    );

    // --- KH?I 2: RESIDUAL UPDATE (C?p nh?t th?ng d?) ---
    residual_update u_res_upd (
        .clk(clk), .rst_n(rst_n),
        .start_update(start_update_reg),
        .current_i(current_i),
        .M_rows(4'd15),
        .q_addr_b(q_addr_b_upd), .q_dout_b(q_dout_b),
        .res_addr_a(res_addr_a), .res_we_a(res_we_a), .res_din_a(res_din_a),
        .res_addr_b(res_addr_b), .res_dout_b(res_dout_b),
        .update_done(update_done)
    );

    /* ==========================================================
       5. MASTER FSM (Sequencer)
    ========================================================== */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mgs_done_all <= 0;
            start_core_reg <= 0;
            start_update_reg <= 0;
        end else begin
            start_core_reg <= 1'b0;   // Ép xung m?c ??nh
            start_update_reg <= 1'b0;

            case (state)
                IDLE: begin
                    mgs_done_all <= 0;
                    if (start_mgs) begin
                        state <= RUN_CORE;
                        start_core_reg <= 1'b1;
                    end
                end

                RUN_CORE: begin
                    state <= WAIT_CORE;
                end

                WAIT_CORE: begin
                    if (core_done) begin
                        state <= RUN_UPDATE;
                        start_update_reg <= 1'b1;
                    end
                end

                RUN_UPDATE: begin
                    state <= WAIT_UPDATE;
                end

                WAIT_UPDATE: begin
                    if (update_done) state <= FINISH;
                end

                FINISH: begin
                    mgs_done_all <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule