////`timescale 1ns / 1ps

////module final_estimation_top #
////(
////    // --- S?a: Tham s? h? th?ng ---
////    parameter NUM_MAC    = 4,      // S? b? MAC song song
////    parameter DW         = 24,     // Q11.13
////    parameter DOT_W      = 56,     // Accumulator width
////    parameter NUM_K      = 16,     // S? nguyên t? (K)
    
////    // --- S?a: Tham s? kích th??c ?nh (M?c ??nh cho 16x16) ---
////    parameter M_TOTAL    = 64,     // T?ng s? phép ?o M
////    parameter ROW_N      = 4,      // Stride: log2(M/NUM_MAC) = 4
////    parameter VW         = 48,     // ?? r?ng ph?n t? vector v
    
////    // --- S?a: Tham s? ??a ch? RAM ---
////    parameter ADDR_W_Y   = 4,      // log2(16) = 4 bit
////    parameter ADDR_W_Q   = 8,      // log2(256) = 8 bit
////    parameter ADDR_W_R   = 8,      // log2(256) = 8 bit
    
////    // --- S?a: Tham s? ??nh d?ng Q-format ---
////    parameter FW_DATA    = 13,
////    parameter FW_ISR     = 22
////)
////(
////    input wire clk,
////    input wire rst_n,
////    input wire start_est,
    
////    // Giao ti?p y_bram
////    output wire [ADDR_W_Y-1:0]  y_addr, // S?a: Dùng ADDR_W_Y
////    input  wire [(NUM_MAC*DW)-1:0] y_dout, // S?a: Dùng NUM_MAC

////    // Giao ti?p q_bram
////    output wire [ADDR_W_Q-1:0]  q_addr, // S?a: Dùng ADDR_W_Q
////    input  wire [(NUM_MAC*DW)-1:0] q_dout, // S?a: Dùng NUM_MAC

////    // Giao ti?p r_bram
////    output wire [ADDR_W_R-1:0]  r_addr, // S?a: Dùng ADDR_W_R
////    input  wire [DW-1:0]        r_dout,

////    // Output k?t qu? x_hat
////    output wire [DW-1:0]        x_hat_val,
////    output wire [$clog2(NUM_K)-1:0] x_hat_idx, // S?a: T? ??ng tính ?? r?ng index
////    output wire                 x_hat_valid,
////    output wire                 done_all
////);

////    // --- S?a: T? ??ng tính t?ng ?? r?ng vector v ---
////    wire [(NUM_K*VW)-1:0] v_flat; 
////    wire v_done;

////    // 1. Tính v = Q^T * y
////    // S?a: Truy?n ??y ?? Parameter vào module con
////    final_v_calc #(
////        .NUM_MAC(NUM_MAC),
////        .DW(DW),
////        .DOT_W(DOT_W),
////        .NUM_K(NUM_K),
////        .M_TOTAL(M_TOTAL),
////        .ROW_N(ROW_N),
////        .VW(VW),
////        .ADDR_W_Y(ADDR_W_Y),
////        .ADDR_W_Q(ADDR_W_Q)
////    ) u_v_calc (
////        .clk(clk), .rst_n(rst_n), .start_v(start_est),
////        .y_addr(y_addr), .y_dout(y_dout),
////        .q_addr(q_addr), .q_dout(q_dout),
////        .v_result_flat(v_flat), .v_done(v_done)
////    );

////    // 2. Gi?i R * x = v
////    // S?a: Truy?n ??y ?? Parameter vào module con
////    final_back_sub #(
////        .DW(DW),
////        .K_MAX(NUM_K),
////        .VW(VW),
////        .ADDR_W_R(ADDR_W_R),
////        .K_W($clog2(NUM_K)+1),
////        .FW_DATA(FW_DATA),
////        .FW_ISR(FW_ISR)
////    ) u_back_sub (
////        .clk(clk), .rst_n(rst_n), .start_bs(v_done),
////        .v_in_flat(v_flat),
////        .r_addr(r_addr), .r_dout(r_dout),
////        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
////        .x_hat_valid(x_hat_valid), .bs_done(done_all)
////    );

////endmodule

//`timescale 1ns / 1ps

//module final_estimation_top #
//(
//    parameter DW = 24
//)
//(
//    input wire clk,
//    input wire rst_n,
//    input wire start_est,
    
//    // Giao ti?p y_bram
//    output wire [3:0]  y_addr,
//    input  wire [95:0] y_dout,

//    // Giao ti?p q_bram
//    output wire [7:0]  q_addr,
//    input  wire [95:0] q_dout,

//    // Giao ti?p r_bram
//    output wire [7:0]  r_addr,
//    input  wire [23:0] r_dout,

//    // Output k?t qu? x_hat
//    output wire [23:0] x_hat_val,
//    output wire [3:0]  x_hat_idx,
//    output wire        x_hat_valid,
//    output wire        done_all
//);

//    wire [767:0] v_flat;
//    wire v_done;

//    // 1. T?nh v = Q^T * y
//    final_v_calc u_v_calc (
//        .clk(clk), .rst_n(rst_n), .start_v(start_est),
//        .y_addr(y_addr), .y_dout(y_dout),
//        .q_addr(q_addr), .q_dout(q_dout),
//        .v_result_flat(v_flat), .v_done(v_done)
//    );

//    // 2. Gi?i R * x = v
//    final_back_sub u_back_sub (
//        .clk(clk), .rst_n(rst_n), .start_bs(v_done),
//        .v_in_flat(v_flat),
//        .r_addr(r_addr), .r_dout(r_dout),
//        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
//        .x_hat_valid(x_hat_valid), .bs_done(done_all)
//    );

//endmodule


`timescale 1ns / 1ps

module final_estimation_top #
(
	parameter NUM_MAC    = 4,
    parameter DW = 24,
	parameter DOT_W      = 56,     // Accumulator width
    parameter NUM_K      = 16,
	parameter VW         = 48,
	parameter ADDR_W_Y   = 4,      // log2(16) = 4 bit
    parameter ADDR_W_Q   = 8,      // log2(256) = 8 bit
    parameter ADDR_W_R   = 8 
)
(
    input wire clk,
    input wire rst_n,
    input wire start_est,
    
    // Giao ti?p y_bram
    output wire [ADDR_W_Y-1:0]  y_addr,
    input  wire [(NUM_MAC*DW)-1:0] y_dout,

    // Giao ti?p q_bram
    output wire [ADDR_W_Q-1:0]  q_addr,
    input  wire [(NUM_MAC*DW)-1:0] q_dout,

    // Giao ti?p r_bram
    output wire [ADDR_W_R-1:0]  r_addr,
    input  wire [DW-1:0] r_dout,

    // Output k?t qu? x_hat
    output wire [DW-1:0] x_hat_val,
    output wire [$clog2(NUM_K)-1:0]  x_hat_idx,
    output wire        x_hat_valid,
    output wire        done_all
);

    wire [(NUM_K*VW)-1:0] v_flat;
    wire v_done;

    // 1. T?nh v = Q^T * y
    final_v_calc u_v_calc (
        .clk(clk), .rst_n(rst_n), .start_v(start_est),
        .y_addr(y_addr), .y_dout(y_dout),
        .q_addr(q_addr), .q_dout(q_dout),
        .v_result_flat(v_flat), .v_done(v_done)
    );

    // 2. Gi?i R * x = v
    final_back_sub u_back_sub (
        .clk(clk), .rst_n(rst_n), .start_bs(v_done),
        .v_in_flat(v_flat),
        .r_addr(r_addr), .r_dout(r_dout),
        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid), .bs_done(done_all)
    );

endmodule