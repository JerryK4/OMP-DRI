`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/21/2026 10:50:07 PM
// Design Name: 
// Module Name: tb_block_a
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

module tb_block_a();

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

    // --- ??u ra t? Block A ---
    wire [5:0]  lambda;
    wire        block_a_done;

    // --- K?t n?i v?i Unit Under Test (Top c?a Block A) ---
    block_a_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_a(start_a),
        .N(N),                  // C?ng DRI m?i
        .M(M),                  // C?ng DRI m?i
        .phi_addr(phi_addr),
        .phi_data(phi_data),
        .r_addr(r_addr),
        .r_data(r_data),
        .lambda(lambda),
        .block_a_done(block_a_done)
    );

    // --- T?o xung Clock (50MHz -> 20ns) ---
    always #10 clk = ~clk;

    // --- Gi? l?p b? nh? BRAM v?i ?? tr? 1 chu k? ---
    reg [95:0] phi_mem_logic;
    reg [95:0] r_mem_logic;

    always @(posedge clk) begin
        // R luôn là 1.0 (Hex: 2000 cho Q10.13)
        r_mem_logic <= {24'h002000, 24'h002000, 24'h002000, 24'h002000};
        
        // Gi? l?p d? li?u cho Phi (m?i c?t 8 dòng):
        // C?t 0: Toàn 1.0
        // C?t 1: Toàn 0.5
        // C?t 2: Toàn -1.1 (S? là Max)
        if (phi_addr[8:3] == 0) 
            phi_mem_logic <= {24'h002000, 24'h002000, 24'h002000, 24'h002000};
        else if (phi_addr[8:3] == 1)
            phi_mem_logic <= {24'h001000, 24'h001000, 24'h001000, 24'h001000};
        else if (phi_addr[8:3] == 2)
            phi_mem_logic <= {24'hFFDCD8, 24'hFFDCD8, 24'hFFDCD8, 24'hFFDCD8}; 
        else
            phi_mem_logic <= {24'h000333, 24'h000333, 24'h000333, 24'h000333};
    end

    assign phi_data = phi_mem_logic;
    assign r_data   = r_mem_logic;

    // --- K?ch b?n ki?m tra DRI ---
    initial begin
        // Kh?i t?o
        clk = 0; rst_n = 0; start_a = 0; N = 0; M = 0;
        #100 rst_n = 1; #40;

        // --- GIAI ?O?N 1: Test ?? phân gi?i 4x4 ---
        $display(">>> Starting Test 1: 4x4 Resolution (N=15, M=1)");
        N = 15; M = 1;
        start_a = 1; #20; start_a = 0;

        wait(block_a_done);
        #100;
        $display("4x4 Result: Winning Column (Lambda) = %d", lambda);
        if (lambda == 2) $display("4x4 Test SUCCESS!");
        else $display("4x4 Test FAILED!");

        #200; // Ngh? m?t chút gi?a 2 l?n ch?y

        // --- GIAI ?O?N 2: Test ?? phân gi?i 8x8 ---
        $display(">>> Starting Test 2: 8x8 Resolution (N=63, M=7)");
        N = 63; M = 7;
        start_a = 1; #20; start_a = 0;

        wait(block_a_done);
        #100;
        $display("8x8 Result: Winning Column (Lambda) = %d", lambda);
        if (lambda == 2) $display("8x8 Test SUCCESS!");
        else $display("8x8 Test FAILED!");

        #100;
        $display("All Block A DRI Tests Finished!");
        $stop;
    end

endmodule
