`timescale 1ns / 1ps

module tb_atom_selection_top;

    // --- Parameters (Kh?p hoàn toàn v?i RTL 24-bit) ---
    parameter DW      = 24;    // Q10.13
    parameter ADDR_W  = 12;    // 4096 rows
    parameter ROW_W   = 6;     
    parameter COL_W   = 8;     // 256 columns
    parameter ROW_N   = 4;     
    parameter DOT_W   = 56;    
    parameter MAX_I   = 16;
    parameter HIST_W  = 9;     // {valid, index}

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg start;
    reg [COL_W-1:0] N_cols;
    reg [ROW_W-1:0] M_rows;
    reg [$clog2(MAX_I):0] current_i;
    reg [MAX_I*HIST_W-1:0] lambda_history;

    wire [ADDR_W-1:0] phi_addr;
    wire [ROW_W-1:0]  r_addr;
    reg  [4*DW-1:0]   phi_data_reg;
    reg  [4*DW-1:0]   r_data_reg;

    wire [COL_W-1:0]  lambda_out;
    wire              atom_done;

    // --- Gi? l?p b? nh? BRAM (96-bit width) ---
    reg [4*DW-1:0] mem_phi [0:4095]; 
    reg [4*DW-1:0] mem_res [0:15];   

    // --- Kh?i DUT (Device Under Test) ---
    atom_selection_top #(
        .DW(DW), .ADDR_W(ADDR_W), .ROW_W(ROW_W), 
        .COL_W(COL_W), .ROW_N(ROW_N), .DOT_W(DOT_W), 
        .MAX_I(MAX_I), .HIST_W(HIST_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .N_cols(N_cols),
        .M_rows(M_rows),
        .phi_addr(phi_addr),
        .phi_data(phi_data_reg),
        .r_addr(r_addr),
        .r_data(r_data_reg),
        .current_i(current_i),
        .lambda_history(lambda_history),
        .lambda_out(lambda_out),
        .atom_done(atom_done)
    );

    // --- Clock Generation (100 MHz) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- BRAM Latency-1 Simulation ---
    // D? li?u xu?t hi?n sau 1 chu k? k? t? khi có ??a ch?
    always @(posedge clk) begin
        phi_data_reg <= mem_phi[phi_addr];
        r_data_reg   <= mem_res[r_addr];
    end

    // --- K?ch b?n Test ---
    integer i;
    initial begin
        // 1. Kh?i t?o
        rst_n = 0;
        start = 0;
        N_cols = 255;  
        M_rows = 15;   
        current_i = 0;
        lambda_history = 0;
        
        for (i = 0; i < 4096; i = i + 1) mem_phi[i] = 0;
        for (i = 0; i < 16; i = i + 1)   mem_res[i] = 0;

        #100;
        rst_n = 1;
        #20;

        // 2. N?p d? li?u Q10.13 (Scale = 2^13 = 8192)
        // Vector r = [1.0, 1.0, ..., 1.0] -> Hex 002000
        for (i = 0; i < 16; i = i + 1) begin
            mem_res[i] = {24'h002000, 24'h002000, 24'h002000, 24'h002000};
        end

        // C?t 75: C?c ??i (M?i ph?n t? = 2.0 -> Hex 004000)
        // K? v?ng Dot Product: 64 * 1.0 * 2.0 = 128.0
        for (i = 0; i < 16; i = i + 1) 
            mem_phi[75*16 + i] = {24'h004000, 24'h004000, 24'h004000, 24'h004000};

        // C?t 120: C?c ??i th? nhì (M?i ph?n t? = 1.5 -> Hex 003000)
        // K? v?ng Dot Product: 64 * 1.0 * 1.5 = 96.0
        for (i = 0; i < 16; i = i + 1) 
            mem_phi[120*16 + i] = {24'h003000, 24'h003000, 24'h003000, 24'h003000};

        // --- TEST CASE 1: Tìm Max (Vòng OMP ??u tiên) ---
        $display("[%t] TEST 1: Tim Max thong thuong. Ky vong Lambda = 75", $time);
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(atom_done);
        #50;
        $display("[%t] KET QUA TEST 1: Lambda Out = %d", $time, lambda_out);
        if (lambda_out == 75) $display(">>> TEST 1: PASSED");
        else $display(">>> TEST 1: FAILED (Expected 75, got %d)", lambda_out);

        #500;

        // --- TEST CASE 2: Masking (Gi? l?p vòng OMP th? 2) ---
        // Chúng ta ??a c?t 75 vào l?ch s? và b?t bit Valid
        $display("[%t] TEST 2: Masking cot 75. Ky vong Lambda = 120", $time);
        current_i = 1;
        lambda_history[HIST_W-1 : 0] = {1'b1, 8'd75}; 
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(atom_done);
        #50;
        $display("[%t] KET QUA TEST 2: Lambda Out = %d", $time, lambda_out);
        if (lambda_out == 120) $display(">>> TEST 2: PASSED");
        else $display(">>> TEST 2: FAILED (Expected 120, got %d)", lambda_out);

        #1000;
        $display("--- HOAN THANH MO PHONG ---");
        $finish;
    end

endmodule