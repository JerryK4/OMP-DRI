`timescale 1ns / 1ps

module block_a_top (
    input wire clk,
    input wire rst_n,
    input wire start_a,
    
    // --- THAM S? DRI ---
    input wire [5:0] N,         // Gi?i h?n s? c?t (15 ho?c 63)
    input wire [2:0] M,         // Gi?i h?n dòng BRAM (1 ho?c 7)
    
    // --- THAM S? MASKING (M?I) ---
    input wire [4:0]  current_i,      // Vòng l?p OMP hi?n t?i (0-15)
    input wire [111:0] lambda_history, // Danh sách 16 lambda c? ?ã ch?n
    
    // Giao ti?p BRAM
    output [8:0]  phi_addr,
    input  [95:0] phi_data,
    output [2:0]  r_addr,
    input  [95:0] r_data,
    
    // K?t qu? ??u ra
    output [5:0]  lambda,
    output        block_a_done
);

    // Dây n?i trung gian gi?a Dot Product và Finding Max
    wire [47:0] w_dot_result;
    wire [5:0]  w_col_idx;
    wire        w_col_done;
    wire        w_all_done;

    // 1. G?i module Dot Product (Gi? nguyên)
    dot_product i_dot_engine (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_a(start_a),
        .N(N),                  
        .M(M),                  
        .phi_addr(phi_addr), 
        .phi_data(phi_data),
        .r_addr(r_addr), 
        .r_data(r_data),
        .dot_result(w_dot_result), 
        .current_col_idx(w_col_idx),
        .col_done(w_col_done), 
        .all_done(w_all_done)
    );

    // 2. G?i module Finding Max (C?P NH?T C?NG MASKING)
    finding_max i_find_max (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_search(start_a),
        .dot_result(w_dot_result),
        .current_col_idx(w_col_idx),
        .col_done(w_col_done),
        .all_done_in(w_all_done),
        .lambda(lambda),
        .finding_done(block_a_done),
        
        // N?i c?ng Masking t? Top xu?ng module con
        .current_i(current_i),
        .lambda_history(lambda_history)
    );

endmodule
