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
