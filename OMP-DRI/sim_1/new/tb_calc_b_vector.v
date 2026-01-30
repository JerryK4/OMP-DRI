`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/23/2026 04:31:03 PM
// Design Name: 
// Module Name: tb_calc_b_vector
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



module tb_calc_b_vector();

    // --- Tín hi?u ?i?u khi?n ---
    reg clk;
    reg rst_n;
    reg start_calc_b;
    reg [4:0] K_final;
    reg [2:0] M_limit;

    // --- Giao ti?p BRAM (Gi? l?p) ---
    wire [6:0]  q_addr;
    reg  [95:0] q_rdata;
    wire [2:0]  y_addr;
    reg  [95:0] y_data;

    // --- ??u ra k?t qu? ---
    wire [3:0]  b_idx;
    wire [23:0] b_val;
    wire        b_we;
    wire        done_b_vec;

    // --- K?t n?i v?i Unit Under Test (UUT) ---
    calc_b_vector uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_calc_b(start_calc_b),
        .K_final(K_final),
        .M_limit(M_limit),
        .q_addr(q_addr),
        .q_rdata(q_rdata),
        .y_addr(y_addr),
        .y_data(y_data),
        .b_idx(b_idx),
        .b_val(b_val),
        .b_we(b_we),
        .done_b_vec(done_b_vec)
    );

    // --- T?o xung Clock 50MHz ---
    always #10 clk = ~clk;

    // --- Gi? l?p d? li?u BRAM (Có tr? 1 chu k?) ---
    // ??nh d?ng Q10.13: 1.0 = hex 2000, 0.5 = hex 1000
    always @(posedge clk) begin
        // Gi? l?p y luôn là vector toàn s? 1.0
        y_data <= {24'h002000, 24'h002000, 24'h002000, 24'h002000};

        // Gi? l?p Q:
        // C?t 0: Toàn 1.0 -> b[0] mong ??i = 32.0 (8 dòng * 4 pt? * 1.0 * 1.0)
        // C?t 1: Toàn 0.5 -> b[1] mong ??i = 16.0 (8 dòng * 4 pt? * 0.5 * 1.0)
        if (q_addr < 8)
            q_rdata <= {24'h002000, 24'h002000, 24'h002000, 24'h002000};
        else if (q_addr >= 8 && q_addr < 16)
            q_rdata <= {24'h001000, 24'h001000, 24'h001000, 24'h001000};
        else
            q_rdata <= 96'd0;
    end

    // --- K?ch b?n ki?m tra ---
    initial begin
        // Kh?i t?o
        clk = 0; rst_n = 0; start_calc_b = 0;
        K_final = 0; M_limit = 0;

        #100 rst_n = 1; #40;

        // --- TEST 1: Tính b cho 2 c?t ??u (K=2), ch? ?? 8x8 (M_limit=7) ---
        $display(">>> Test 1: Calculating b-vector for K=2, 8x8 mode");
        K_final = 2;
        M_limit = 7;
        #20 start_calc_b = 1; #20 start_calc_b = 0;

        // ??i xong
        wait(done_b_vec);
        #100;

        $display(">>> Simulation Finished!");
        $stop;
    end

    // --- Monitor k?t qu? ---
    always @(posedge clk) begin
        if (b_we) begin
            // 32.0 trong Q10.13 là 32 * 2^13 = 262144 (Hex: 40000)
            // 16.0 trong Q10.13 là 16 * 2^13 = 131072 (Hex: 20000)
            $display("Time: %t | b[%d] = %h (Expected 40000 for idx 0, 20000 for idx 1)", 
                     $time, b_idx, b_val);
        end
    end

endmodule
