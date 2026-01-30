`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/26/2026 10:56:12 PM
// Design Name: 
// Module Name: tb_omp_system_dri
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


module tb_omp_system_dri();
    reg clk;
    reg rst_n;
    reg start_system;
    reg [5:0] N_in;
    reg [2:0] M_in;
    reg [4:0] K_limit;

    wire [5:0]  pixel_addr;
    wire [23:0] pixel_val;
    wire        pixel_we;
    wire        done_all;

    // --- K?t n?i Module Top ---
    omp_system_top uut (
        .clk(clk), .rst_n(rst_n), .start_system(start_system),
        .N_in(N_in), .M_in(M_in), .K_limit(K_limit),
        .pixel_val(pixel_val), .pixel_addr(pixel_addr), .pixel_we(pixel_we),
        .done_all(done_all)
    );

    always #10 clk = ~clk;

    integer file_4x4, file_8x8;
    reg dri_stage; // 0: 4x4, 1: 8x8

    initial begin
        // T?o 2 file riêng bi?t ?? l?u 2 giai ?o?n
        file_4x4 = $fopen("dri_stage_4x4.txt", "w");
        file_8x8 = $fopen("dri_stage_8x8.txt", "w");
    end

    // Ghi d? li?u d?a vào giai ?o?n DRI hi?n t?i
    always @(posedge clk) begin
        if (pixel_we) begin
            if (dri_stage == 0) $fdisplay(file_4x4, "%d %h", pixel_addr, pixel_val);
            else                $fdisplay(file_8x8, "%d %h", pixel_addr, pixel_val);
        end
    end

    initial begin
        // Kh?i t?o
        clk = 0; rst_n = 0; start_system = 0; dri_stage = 0;
        #100 rst_n = 1; #100;

        // --- GIAI ?O?N 1: Tái t?o m?c th?p 4x4 ---
        $display(">>> DRI STAGE 1: 4x4 Resolution (Low-Res Preview)");
        N_in = 15;    // 16 pixel
        M_in = 1;     // 8 phép ?o (2 dòng BRAM)
        K_limit = 4;  // Sparsity m?c th?p
        
        #20 start_system = 1; #20 start_system = 0;
        wait(done_all);
        $display(">>> Stage 1 Finished!");

        #1000; // Ngh? 1 chút ?? chuy?n giai ?o?n

        // --- GIAI ?O?N 2: Tinh ch?nh lên m?c cao 8x8 ---
        $display(">>> DRI STAGE 2: 8x8 Resolution (Progressive Refinement)");
        dri_stage = 1; 
        N_in = 63;    // 64 pixel
        M_in = 7;     // 32 phép ?o (8 dòng BRAM)
        K_limit = 16; // Sparsity ??y ??
        
        #20 start_system = 1; #20 start_system = 0;
        wait(done_all);

        #100;
        $fclose(file_4x4);
        $fclose(file_8x8);
        $display(">>> DRI Process Completed! Files saved.");
        $stop;
    end
endmodule