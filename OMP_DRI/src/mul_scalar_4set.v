`timescale 1ns / 1ps

module mul_scalar_4set #
(
    // --- S?a: Tham s? hóa ?? r?ng và s? l??ng b? nhân ---
    parameter DW      = 24,    // ?? r?ng d? li?u (Data Width)
    parameter SW      = 24,    // ?? r?ng s? vô t? (Scalar Width)
    parameter NUM_SET = 4      // S?a: S? l??ng ph?n t? x? lý song song (m?c ??nh là 4)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [(NUM_SET*DW)-1:0] v_in,     // S?a: Dùng NUM_SET
    input  wire signed [SW-1:0]    scalar,
    input  wire [5:0]              shift, 
    output reg  [(NUM_SET*DW)-1:0] v_out     // S?a: Dùng NUM_SET
);
    // --- S?a: Unpack d? li?u dùng m?ng và vòng l?p ---
    wire signed [DW-1:0] v [0:NUM_SET-1];
    genvar i;
    generate
        for (i = 0; i < NUM_SET; i = i + 1) begin : unpack_v
            assign v[i] = v_in[i*DW +: DW];
        end
    endgenerate

    // --- S?a: Khai báo thanh ghi trung gian (Stage 1) ---
    reg signed [DW+SW-1:0] m [0:NUM_SET-1];
    
    // --- S?a: T? ??ng tính toán ng??ng bão hòa theo DW ---
    localparam signed [DW-1:0] MAX_POS = {1'b0, {(DW-1){1'b1}}}; // 0111...1
    localparam signed [DW-1:0] MAX_NEG = {1'b1, {(DW-1){1'b0}}}; // 1000...0

    // --- Logic x? lý: Gi? nguyên c?u trúc 2 giai ?o?n (Pipeline) ---
    integer j;
    always @(posedge clk) begin
        // Stage 1: Nhân (Dùng vòng l?p ?? thay th? vi?c vi?t tay m0, m1...)
        for (j = 0; j < NUM_SET; j = j + 1) begin
            m[j] <= v[j] * scalar;
        end

        // Stage 2: D?ch bit + Bão hòa (Saturation logic)
        for (j = 0; j < NUM_SET; j = j + 1) begin
            v_out[j*DW +: DW] <= saturate(m[j] >>> shift);
        end
    end

    // --- Hàm n?i b? ?? bão hòa s? (Tham s? hóa ?? r?ng ??u vào) ---
    function [DW-1:0] saturate(input signed [DW+SW-1:0] val);
        if (val > $signed({ {(SW){1'b0}}, MAX_POS })) 
            saturate = MAX_POS;
        else if (val < $signed({ {(SW){1'b1}}, MAX_NEG })) 
            saturate = MAX_NEG;
        else 
            saturate = val[DW-1:0];
    endfunction

endmodule