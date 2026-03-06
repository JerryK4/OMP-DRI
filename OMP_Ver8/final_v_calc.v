//`timescale 1ns / 1ps

//module final_v_calc #
//(
//    parameter DW = 24,         // Q10.13
//    parameter ADDR_W_Q = 8,    // 256 h?ng
//    parameter DOT_W = 56,      // Accumulator width
//    parameter NUM_K = 16       // S? nguy?n t? (K=16)
//)
//(
//    input wire clk,
//    input wire rst_n,
//    input wire start_v,
    
//    // Giao ti?p y_bram (Read Only)
//    output wire [3:0]  y_addr,
//    input  wire [95:0] y_dout,

//    // Giao ti?p q_bram (Read Only)
//    output wire [7:0]  q_addr,
//    input  wire [95:0] q_dout,

//    // Output: Vector v ?? tr?i ph?ng (16 ph?n t? * 48 bit = 768 bit)
//    // M?i ph?n t? v[i] chi?m ?o?n [i*48 +: 48]
//    output reg [767:0] v_result_flat,
//    output reg         v_done
//);

//    // --- FSM States ---
//    localparam IDLE  = 2'd0,
//               CALC  = 2'd1,
//               DONE_ST = 2'd2;

//    reg [1:0] state;
//    reg [3:0] i_cnt; // Duy?t qua 16 c?t c?a Q (i = 0..15)

//    // T?n hi?u k?t n?i v?i b? MAC
//    wire mac_all_done;
//    wire [DOT_W-1:0] mac_val;
//    wire [3:0] mac_row_cnt;
//    reg  start_mac_reg;

//    /* ==========================================================
//       1. KH?I T?NH T?CH V? H??NG (REUSE MAC)
//    ========================================================== */
//    dot_product_4mac #(
//        .DW(24), 
//        .OUT_W(56), 
//        .ROW_W(4)
//    ) u_mac_v (
//        .clk(clk), 
//        .rst_n(rst_n), 
//        .start_a(start_mac_reg),
//        .N_cols(8'd0),   // Lu?n t?nh 1 c?t m?i l?n g?i
//        .M_rows(4'd15),  // 16 h?ng (64 ph?n t?)
//        .phi_data(q_dout), 
//        .r_data(y_dout),
//        .dot_result(mac_val), 
//        .all_done(mac_all_done),
//        .row_cnt_out(mac_row_cnt),
//        .phi_addr(), 
//        .r_addr()
//    );

//    // ?i?u khi?n ??a ch? RAM d?a tr?n nh?p c?a b? MAC
//    // q_addr: tr? v?o c?t i_cnt, h?ng mac_row_cnt
//    assign q_addr = (i_cnt << 4) + mac_row_cnt;
//    // y_addr: tr? v?o h?ng mac_row_cnt c?a vector ?o y
//    assign y_addr = mac_row_cnt;

//    /* ==========================================================
//       2. MASTER FSM CHO KH?I V_CALC
//    ========================================================== */
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= IDLE;
//            v_done <= 1'b0;
//            i_cnt <= 4'd0;
//            v_result_flat <= 768'd0;
//            start_mac_reg <= 1'b0;
//        end else begin
//            case (state)
//                IDLE: begin
//                    v_done <= 1'b0;
//                    if (start_v) begin
//                        state <= CALC;
//                        i_cnt <= 4'd0;
//                        start_mac_reg <= 1'b1; // K?ch ho?t MAC v?ng ??u
//                    end
//                end

//                CALC: begin
//                    start_mac_reg <= 1'b0; // T?t xung start sau 1 nh?p

//                    if (mac_all_done) begin
//                        // L?u k?t qu? 48-bit v?o v? tr? t??ng ?ng trong vector ph?ng
//                        // Ch?ng ta gi? l?i 48-bit ?? b?o to?n ?? ch?nh x?c Q26
//                        v_result_flat[i_cnt * 48 +: 48] <= mac_val[47:0];

//                        if (i_cnt == 4'd15) begin
//                            state <= DONE_ST;
//                        end else begin
//                            i_cnt <= i_cnt + 1'b1;
//                            start_mac_reg <= 1'b1; // K?ch ho?t MAC cho c?t ti?p theo
//                            state <= CALC;
//                        end
//                    end
//                end

//                DONE_ST: begin
//                    v_done <= 1'b1;
//                    state <= IDLE;
//                end

//                default: state <= IDLE;
//            endcase
//        end
//    end

//endmodule


`timescale 1ns / 1ps

module final_v_calc #
(
	parameter NUM_MAC = 4,
    parameter DW = 24,         // Q10.13
    parameter ROW_N      = 4,
    parameter ADDR_W_Q = 8,    // 256 h?ng
	parameter ADDR_W_Y     = 4,
    parameter DOT_W = 56,      // Accumulator width
	parameter VW         = 48,
    parameter NUM_K = 16       // S? nguy?n t? (K=16)
)
(
    input wire clk,
    input wire rst_n,
    input wire start_v,
    
    // Giao ti?p y_bram (Read Only)
    output wire [ADDR_W_Y-1:0]  y_addr,
    input  wire [(NUM_MAC*DW)-1:0] y_dout,

    // Giao ti?p q_bram (Read Only)
    output wire [ADDR_W_Q-1:0]  q_addr,
    input  wire [(NUM_MAC*DW)-1:0] q_dout,

    // Output: Vector v ?? tr?i ph?ng (16 ph?n t? * 48 bit = 768 bit)
    // M?i ph?n t? v[i] chi?m ?o?n [i*48 +: 48]
    output reg [(NUM_K*VW)-1:0] v_result_flat,
    output reg         v_done
);

    // --- FSM States ---
    localparam IDLE  = 2'd0,
               CALC  = 2'd1,
               DONE_ST = 2'd2;

    reg [1:0] state;
    reg [$clog2(NUM_K)-1:0] i_cnt; // Duy?t qua 16 c?t c?a Q (i = 0..15)

    // T?n hi?u k?t n?i v?i b? MAC
    wire mac_all_done;
    wire [DOT_W-1:0] mac_val;
    wire [ADDR_W_Y-1:0] mac_row_cnt;
    reg  start_mac_reg;

    /* ==========================================================
       1. KH?I T?NH T?CH V? H??NG (REUSE MAC)
    ========================================================== */
    dot_product_4mac #(
        .DW(24), 
        .OUT_W(56), 
        .ROW_W(4)
    ) u_mac_v (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_a(start_mac_reg),
//        .N_cols(8'd0),   // Lu?n t?nh 1 c?t m?i l?n g?i
//        .M_rows(4'd15),  // 16 h?ng (64 ph?n t?)
        .N_cols(0), 
        .M_rows(NUM_K-1),
        .phi_data(q_dout), 
        .r_data(y_dout),
        .dot_result(mac_val), 
        .all_done(mac_all_done),
        .row_cnt_out(mac_row_cnt),
        .phi_addr(), 
        .r_addr()
    );

    // ?i?u khi?n ??a ch? RAM d?a tr?n nh?p c?a b? MAC
    // q_addr: tr? v?o c?t i_cnt, h?ng mac_row_cnt
    assign q_addr = (i_cnt << ROW_N) + mac_row_cnt;
    // y_addr: tr? v?o h?ng mac_row_cnt c?a vector ?o y
    assign y_addr = mac_row_cnt;

    /* ==========================================================
       2. MASTER FSM CHO KH?I V_CALC
    ========================================================== */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            v_done <= 0;
            i_cnt <= 0;
            v_result_flat <= 0;
            start_mac_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    v_done <= 1'b0;
                    if (start_v) begin
                        state <= CALC;
                        i_cnt <= 0;
                        start_mac_reg <= 1'b1; // K?ch ho?t MAC v?ng ??u
                    end
                end

                CALC: begin
                    start_mac_reg <= 1'b0; // T?t xung start sau 1 nh?p

                    if (mac_all_done) begin
                        v_result_flat[i_cnt * VW +: VW] <= mac_val[VW-1:0];

                        if (i_cnt == NUM_K-1) begin
                            state <= DONE_ST;
                        end else begin
                            i_cnt <= i_cnt + 1'b1;
                            start_mac_reg <= 1'b1; // K?ch ho?t MAC cho c?t ti?p theo
                            state <= CALC;
                        end
                    end
                end

                DONE_ST: begin
                    v_done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule