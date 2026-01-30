`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/21/2026 11:08:45 PM
// Design Name: 
// Module Name: tb_final_block_a
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

module tb_final_block_a();
    reg clk;
    reg rst_n;
    reg start_all;
    reg [5:0] N; // Thêm thanh ghi N
    reg [2:0] M; // Thêm thanh ghi M
    
    wire [5:0] lambda;
    wire done_all;

    // C?p nh?t ph?n g?i module (instantiation)
    top_test_block_a dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_all(start_all),
        .N(N),          // N?i c?ng N
        .M(M),          // N?i c?ng M
        .lambda(lambda),
        .done_all(done_all)
    );

    // T?o xung clock 50MHz
    always #10 clk = ~clk;

    initial begin
        // --- Kh?i t?o ban ??u ---
        clk = 0; rst_n = 0; start_all = 0; N = 0; M = 0;
        #100 rst_n = 1;
        #100;

        // --- TEST CH? ?? 1: ?? phân gi?i 4x4 ---
        $display(">>> RUNNING DRI TEST: 4x4 Resolution (N=15, M=1)");
        N = 15; 
        M = 1; // Copy 2 dòng BRAM y sang R (t??ng ???ng 8 ph?n t?)
        
        #20 start_all = 1;
        #20 start_all = 0;
        
        wait(done_all);
        $display("4x4 RESULT - Winning Column (Lambda): %d", lambda);
        
        #500; // Ngh? gi?a 2 l?n ch?y

        // --- TEST CH? ?? 2: ?? phân gi?i 8x8 ---
        $display(">>> RUNNING DRI TEST: 8x8 Resolution (N=63, M=7)");
        N = 63; 
        M = 7; // Copy ?? 8 dòng BRAM y sang R (t??ng ???ng 32 ph?n t?)
        
        #20 start_all = 1;
        #20 start_all = 0;
        
        wait(done_all);
        $display("8x8 RESULT - Winning Column (Lambda): %d", lambda);
        
        #100;
        $display("--- ALL BRAM DATA TESTS FINISHED ---");
        $stop;
    end
endmodule