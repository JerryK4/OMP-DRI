`timescale 1ns / 1ps

module atom_selection_top #
(
    parameter DW      = 24,    // ??nh d?ng 24-bit (Q10.13)
    parameter ADDR_W  = 12,    // ??a ch? Phi RAM (4096 hàng)
    parameter ROW_W   = 6,     // ??a ch? r RAM (16 hàng cho M=64)
    parameter COL_W   = 8,     // Index c?t (0..255)
    parameter ROW_N   = 4,     // 2^4 = 16 hàng m?i c?t
    parameter DOT_W   = 56,    // K?t qu? tích vô h??ng (kh?p v?i OUT_W c?a MAC)
    parameter MAX_I   = 16,    // Sparsity K t?i ?a
    parameter HIST_W  = 9      // {valid_bit, index[7:0]}
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start,         // Xung kích ho?t t? FSM t?ng c?a OMP

    // Tham s? c?u hình (??ng cho DRI)
    input  wire [COL_W-1:0] N_cols, 
    input  wire [ROW_W-1:0] M_rows, 

    // Giao ti?p BRAM Ma tr?n Phi
    output wire [ADDR_W-1:0] phi_addr,
    input  wire [4*DW-1:0]   phi_data,

    // Giao ti?p BRAM Th?ng d? r
    output wire [ROW_W-1:0]  r_addr,
    input  wire [4*DW-1:0]   r_data,

    // Masking Control (Support Set)
    input  wire [$clog2(MAX_I):0]  current_i,
    input  wire [MAX_I*HIST_W-1:0] lambda_history,

    // Output k?t qu?
    output wire [COL_W-1:0] lambda_out, 
    output wire             atom_done   
);

    /* --- Tín hi?u dây k?t n?i n?i b? gi?a các kh?i --- */
    wire [DOT_W-1:0] w_dot_result;
    wire [COL_W-1:0] w_current_col;
    wire [ROW_W-1:0] w_row_cnt_unused; // Dây b? sung ?? ?? 14 c?ng
    wire             w_col_done;
    wire             w_all_done;

    /* ==========================================================
       1. Kh?i Parallel Dot Product (Tính tích vô h??ng 4 nhân)
       K?t n?i ??y ?? 14 c?ng theo ?úng ??nh ngh?a c?a module
    ========================================================== */
    dot_product_4mac #(
        .ADDR_W(ADDR_W),
        .ROW_W(ROW_W),
        .COL_W(COL_W),
        .ROW_N(ROW_N),
        .DW(DW),
        .ACC_W(56),      
        .OUT_W(DOT_W)    
    ) u_parallel_mac (
        .clk(clk),
        .rst_n(rst_n),
        .start_a(start),
        
        .N_cols(N_cols),
        .M_rows(M_rows),
        
        .phi_addr(phi_addr),
        .phi_data(phi_data),
        
        .r_addr(r_addr),
        .r_data(r_data),
        
        .dot_result(w_dot_result),
        .current_col_idx(w_current_col),
        .row_cnt_out(w_row_cnt_unused), // ?ã thêm c?ng b? thi?u ? ?ây
        .col_done(w_col_done),
        .all_done(w_all_done)
    );

    /* ==========================================================
       2. Kh?i Finding Max (Comparator + Masking logic)
       Nh?n k?t qu? t? MAC và tìm ra Lambda t?t nh?t không b? Mask
    ========================================================== */
    finding_max #(
        .DOT_W(DOT_W),   
        .COL_W(COL_W),   
        .MAX_I(MAX_I),
        .HIST_W(HIST_W)
    ) u_comparator_max (
        .clk(clk),
        .rst_n(rst_n),
        .start_search(start),
        
        .dot_result(w_dot_result),
        .current_col_idx(w_current_col),
        .col_done(w_col_done),
        .all_done_in(w_all_done),
        
        .current_i(current_i),
        .lambda_history(lambda_history),
        
        .lambda(lambda_out),
        .finding_done(atom_done)
    );

endmodule