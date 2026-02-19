`timescale 1ns / 1ps

module residual_update_system_top #
(
    parameter DW = 24,
    parameter ADDR_W_Q = 8,    // 256 hàng cho ma tr?n Q
    parameter DOT_W = 56
)
(
    input wire clk,
    input wire rst_n,
    input wire start_update,
    input wire [4:0] current_i, // Ch? s? c?t Q v?a ???c t?o ra
    input wire [3:0] M_rows,    // 15 cho 16x16

    // Output quan sát (Dành cho Debug/ILA)
    output wire update_done,
    output wire [DW-1:0]    debug_alpha_val, // Giá tr? Alpha = <Qi, r_old>
    output wire [95:0]      debug_res_dout   // Soi giá tr? th?ng d? r ?ang ??c ra
);

    // --- Tín hi?u k?t n?i n?i b? (Buses) ---
    wire [ADDR_W_Q-1:0]   q_addr_b_bus;
    wire [95:0]           q_dout_b_bus;

    wire [3:0]            res_addr_a_bus; 
    wire                  res_we_a_bus;
    wire [95:0]           res_din_a_bus;
    wire [3:0]            res_addr_b_bus; 
    wire [95:0]           res_dout_b_bus;

    // =====================================================
    // 1. KH?I T?O KH?I RESIDUAL UPDATE (DUT)
    // =====================================================
    residual_update #(
        .DW(DW), 
        .ADDR_W_Q(ADDR_W_Q), 
        .DOT_W(DOT_W)
    ) u_residual_upd (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_update(start_update),
        .current_i(current_i), 
        .M_rows(M_rows),
        
        // Giao ti?p Q BRAM (Ch? ??c Port B)
        .q_addr_b(q_addr_b_bus),
        .q_dout_b(q_dout_b_bus),
        
        // Giao ti?p Residual RAM (??c Port B, Ghi Port A)
        .res_addr_a(res_addr_a_bus),
        .res_we_a(res_we_a_bus),
        .res_din_a(res_din_a_bus),
        .res_addr_b(res_addr_b_bus),
        .res_dout_b(res_dout_b_bus),
        
        .update_done(update_done)
    );

    // --- Peeking Signals ?? Debug (Gi?ng cách làm ? kh?i Core) ---
    assign debug_alpha_val = u_residual_upd.alpha_reg; // Soi h? s? t??ng quan
    assign debug_res_dout  = res_dout_b_bus;          // Soi vector th?ng d? r

    /* ==========================================================
       2. KH?I T?O CÁC IP BLOCK RAM (Xilinx BMG)
    ========================================================== */

    // Ma tr?n tr?c giao Q (True Dual Port)
    // Port A: Có th? n?i v?i kh?i Core ?? ghi Qi m?i
    // Port B: Kh?i Residual Update dùng ?? ??c Qi
    q_bram u_q_memory (
        .clka(clk),
        .wea(1'b0),        // Test ??c l?p nên Port A không ghi
        .addra(8'd0),
        .dina(96'd0),
        .douta(),

        .clkb(clk),
        .web(1'b0),        // Port B ch? ??c
        .addrb(q_addr_b_bus),
        .dinb(96'd0),
        .doutb(q_dout_b_bus)
    );

    // RAM Th?ng d? (Simple Dual Port)
    // Port A: Nh?n th?ng d? m?i (r_new) sau khi ?ã tr? hình chi?u
    // Port B: ??y th?ng d? c? (r_old) ra cho kh?i tính toán
    res_vec_ram u_residual_memory (
        .clka(clk),
        .wea(res_we_a_bus),
        .addra(res_addr_a_bus),
        .dina(res_din_a_bus),

        .clkb(clk),
        .addrb(res_addr_b_bus),
        .doutb(res_dout_b_bus)
    );

endmodule