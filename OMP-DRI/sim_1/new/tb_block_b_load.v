`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 04:11:12 PM
// Design Name: 
// Module Name: tb_block_b_load
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


module tb_block_b_load();

    // --- Tín hi?u ?i?u khi?n ---
    reg clk;
    reg rst_n;
    reg start_b;
    reg [5:0] lambda;
    reg [2:0] M_limit;

    // --- Giao ti?p BRAM (Gi? l?p) ---
    wire [8:0] phi_addr;
    reg  [95:0] phi_data;

    // --- ??u ra ---
    wire [2:0] state_out;

    // --- K?t n?i v?i Module Block B (UUT) ---
    block_b_mgs uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_b(start_b),
        .lambda(lambda),
        .M_limit(M_limit),
        .phi_addr(phi_addr),
        .phi_data(phi_data),
        .state_out(state_out)
    );

    // --- T?o xung Clock 50MHz ---
    always #10 clk = ~clk;

    // --- Gi? l?p BRAM Phi v?i ?? tr? 1 chu k? ---
    // T?o d? li?u m?u: m?i ô nh? tr? v? giá tr? chính là ??a ch? c?a nó
    // ?? chúng ta d? ki?m tra xem d? li?u có b? l?ch dòng hay không.
    always @(posedge clk) begin
        // D? li?u tr? v? có d?ng: [addr][addr][addr][addr] (m?i ph?n t? 24 bit)
        phi_data <= { {15'd0, phi_addr}, {15'd0, phi_addr}, {15'd0, phi_addr}, {15'd0, phi_addr} };
    end

    // --- K?ch b?n ki?m tra ---
    initial begin
        // Kh?i t?o
        clk = 0; rst_n = 0; start_b = 0; lambda = 0; M_limit = 0;
        #100 rst_n = 1; #40;

        // --- TEST 1: Load c?t lambda = 10, ch? ?? 8x8 (M_limit = 7) ---
        $display(">>> Test 1: Loading Column 10 (8x8 mode)");
        lambda = 10;
        M_limit = 7;
        #20 start_b = 1; #20 start_b = 0;

        // ??i n?p xong (tr?ng thái quay v? IDLE ho?c d?a vào s? chu k?)
        #300; 

        // --- TEST 2: Load c?t lambda = 50, ch? ?? 4x4 (M_limit = 1) ---
        $display(">>> Test 2: Loading Column 50 (4x4 mode)");
        lambda = 50;
        M_limit = 1;
        #20 start_b = 1; #20 start_b = 0;

        #200;
        $display("Simulation Finished!");
        $stop;
    end

endmodule
