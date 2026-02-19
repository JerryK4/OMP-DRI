`timescale 1ns / 1ps

module tb_mgs_sub_mul;

    // Parameters
    parameter DW = 24;
    
    // Signals
    reg clk;
    reg rst_n;
    
    // --- Signals for sub_4set ---
    reg  [4*DW-1:0] sub_a;
    reg  [4*DW-1:0] sub_b;
    wire [4*DW-1:0] sub_res;
    
    // --- Signals for mul_scalar (MGS - Shift 13) ---
    reg  [4*DW-1:0] mul13_v_in;
    reg  signed [DW-1:0] mul13_scalar;
    wire [4*DW-1:0] mul13_v_out;
    
    // --- Signals for mul_scalar (Normalization - Shift 22) ---
    reg  [4*DW-1:0] mul22_v_in;
    reg  signed [DW-1:0] mul22_scalar;
    wire [4*DW-1:0] mul22_v_out;

    // 1. Kh?i t?o Module Tr?
    sub_4set #(.DW(DW)) u_sub (
        .clk(clk), .rst_n(rst_n),
        .a_vec(sub_a), .b_vec(sub_b),
        .res_vec(sub_res)
    );

    // 2. Kh?i t?o Module Nhân (Q10.13 * Q10.13 -> Shift 13)
    mul_scalar_4set #(.DW(DW), .SHIFT(13)) u_mul_mgs (
        .clk(clk), .rst_n(rst_n),
        .v_in(mul13_v_in), .scalar(mul13_scalar),
        .v_out(mul13_v_out)
    );

    // 3. Kh?i t?o Module Nhân (Q10.13 * Q2.22 -> Shift 22)
    mul_scalar_4set #(.DW(DW), .SHIFT(22)) u_mul_norm (
        .clk(clk), .rst_n(rst_n),
        .v_in(mul22_v_in), .scalar(mul22_scalar),
        .v_out(mul22_v_out)
    );

    // Clock Gen
    initial clk = 0;
    always #5 clk = ~clk;

    // ??nh ngh?a các h?ng s? Q-format ?? d? n?p d? li?u
    // Q10.13: 1.0 = 2^13 = 8192 (Hex 2000)
    localparam Q13_1_0 = 24'h002000;
    localparam Q13_0_5 = 24'h001000;
    localparam Q13_2_0 = 24'h004000;
    localparam Q13_NEG_1 = 24'hFFE000; // -1.0
    
    // Q2.22: 1.0 = 2^22 = 4194304 (Hex 400000)
    localparam Q22_0_5 = 24'h200000; // 0.5 (dùng cho ISR output gi? l?p)

    initial begin
        // Reset
        rst_n = 0;
        sub_a = 0; sub_b = 0;
        mul13_v_in = 0; mul13_scalar = 0;
        mul22_v_in = 0; mul22_scalar = 0;
        #100;
        rst_n = 1;
        #20;

        // --- TEST 1: Phép tr? vector (1 nh?p tr?) ---
        // A = {2.0, 1.0, 0.5, -1.0}, B = {1.0, 0.5, 0.25, 0.5}
        sub_a = {Q13_2_0, Q13_1_0, Q13_0_5, Q13_NEG_1};
        sub_b = {Q13_1_0, Q13_0_5, 24'h000800, Q13_0_5}; 
        
        #10; // ??i 1 chu k? clk
        $display("[%t] TEST SUB: {1.0, 0.5, 0.25, -1.5}?", $time);
        $display("Result: {%h, %h, %h, %h}", 
                  sub_res[95:72], sub_res[71:48], sub_res[47:24], sub_res[23:0]);

        // --- TEST 2: Nhân Scalar MGS (Shift 13, 2 nh?p tr?) ---
        // K?ch b?n: w = scalar * Q. Gi? s? Q={1, 1, 1, 1}, scalar = 0.5
        mul13_v_in = {Q13_1_0, Q13_1_0, Q13_1_0, Q13_1_0};
        mul13_scalar = Q13_0_5; // 0.5
        
        #20; // ??i 2 chu k? clk (Stage 1: Mul, Stage 2: Shift/Reg)
        $display("[%t] TEST MUL Q13: {0.5, 0.5, 0.5, 0.5}?", $time);
        $display("Result: {%h, %h, %h, %h}", 
                  mul13_v_out[95:72], mul13_v_out[71:48], mul13_v_out[47:24], mul13_v_out[23:0]);

        // --- TEST 3: Nhân Scalar Normalization (Shift 22, 2 nh?p tr?) ---
        // K?ch b?n: Q_new = w * ISR. Gi? s? w={1, 2, -1, 0.5}, ISR = 0.5 (Q22)
        mul22_v_in = {Q13_1_0, Q13_2_0, Q13_NEG_1, Q13_0_5};
        mul22_scalar = Q22_0_5; // 0.5 ??nh d?ng Q2.22
        
        #20;
        $display("[%t] TEST MUL Q22 (ISR): {0.5, 1.0, -0.5, 0.25}?", $time);
        $display("Result: {%h, %h, %h, %h}", 
                  mul22_v_out[95:72], mul22_v_out[71:48], mul22_v_out[47:24], mul22_v_out[23:0]);

        #100;
        $display("--- KET THUC MO PHONG ---");
        $finish;
    end

endmodule