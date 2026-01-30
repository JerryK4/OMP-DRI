`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/21/2026 09:03:57 PM
// Design Name: 
// Module Name: tb_dot_product
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module tb_dot_product();

    // --- Tín hi?u ?i?u khi?n ---
    reg clk;
    reg rst_n;
    reg start_a;
    reg [5:0] N;
    reg [2:0] M;

    // --- Giao ti?p BRAM (Gi? l?p) ---
    wire [8:0]  phi_addr;
    wire [95:0] phi_data;
    wire [2:0]  r_addr;
    wire [95:0] r_data;

    // --- ??u ra t? Engine ---
    wire [47:0] dot_result;
    wire [5:0]  current_col_idx;
    wire        col_done;
    wire        all_done;

    // --- K?t n?i v?i Unit Under Test (UUT) ---
    dot_product uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_a(start_a),
        .N(N),
        .M(M),
        .phi_addr(phi_addr),
        .phi_data(phi_data),
        .r_addr(r_addr),
        .r_data(r_data),
        .dot_result(dot_result),
        .current_col_idx(current_col_idx),
        .col_done(col_done),
        .all_done(all_done)
    );

    // --- T?o xung Clock (50MHz -> 20ns) ---
    always #10 clk = ~clk;

    // --- Gi? l?p b? nh? BRAM v?i ?? tr? 1 chu k? ---
    reg [95:0] phi_mem_logic;
    reg [95:0] r_mem_logic;

    always @(posedge clk) begin
        // R luôn là 1.0 (Hex: 2000 cho Q10.13)
        r_mem_logic <= {24'h002000, 24'h002000, 24'h002000, 24'h002000};
        
        // Gi? l?p Phi: C?t 0 = 1.0, C?t 1 = 0.5, C?t 2 = -1.0
        if (phi_addr[8:3] == 0)      // C?t 0 (??a ch? 0-7)
            phi_mem_logic <= {24'h002000, 24'h002000, 24'h002000, 24'h002000};
        else if (phi_addr[8:3] == 1) // C?t 1 (??a ch? 8-15)
            phi_mem_logic <= {24'h001000, 24'h001000, 24'h001000, 24'h001000};
        else if (phi_addr[8:3] == 2) // C?t 2 (??a ch? 16-23)
            phi_mem_logic <= {24'hFFE000, 24'hFFE000, 24'hFFE000, 24'hFFE000};
        else
            phi_mem_logic <= 96'h0;
    end

    assign phi_data = phi_mem_logic;
    assign r_data   = r_mem_logic;

    // --- K?ch b?n ki?m tra ---
    initial begin
        // Kh?i t?o
        clk = 0; rst_n = 0; start_a = 0; N = 0; M = 0;

        #100 rst_n = 1; #40;

        // --- TEST 1: ?nh 4x4 (N=15, M=1) ---
        // T?i 4x4, m?i c?t ch? tính 2 dòng BRAM (8 ph?n t?)
        $display("--- Testing 4x4 Resolution (N=15, M=1) ---");
        N = 15; M = 1;
        start_a = 1; #20; start_a = 0;

        wait(all_done);
        #100;

        // --- TEST 2: ?nh 8x8 (N=63, M=7) ---
        // T?i 8x8, m?i c?t tính ?? 8 dòng BRAM (32 ph?n t?)
        $display("--- Testing 8x8 Resolution (N=63, M=7) ---");
        N = 63; M = 7;
        start_a = 1; #20; start_a = 0;

        wait(all_done);
        #100;
        $display("All DRI Simulations Finished!");
        $stop;
    end

    // --- Monitor & Verify ---
    always @(posedge clk) begin
        if (col_done) begin
            $display("Res: %s | Col: %d | Result: %h", 
                     (M == 1) ? "4x4" : "8x8", current_col_idx, dot_result);
            
            // Ki?m tra toán h?c:
            if (M == 1 && current_col_idx == 0) begin // 4x4, Col 0: 8 pt? * 1.0 = 8.0
                if (dot_result !== 48'h20000000) $display("ERROR: 4x4 Col 0 failed!");
            end
            
            if (M == 7 && current_col_idx == 0) begin // 8x8, Col 0: 32 pt? * 1.0 = 32.0
                if (dot_result !== 48'h80000000) $display("ERROR: 8x8 Col 0 failed!");
            end
        end
    end

endmodule
