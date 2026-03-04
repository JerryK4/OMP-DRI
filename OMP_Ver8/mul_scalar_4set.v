`timescale 1ns / 1ps

module mul_scalar_4set #(
    parameter DW = 24,
    parameter SW = 24
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [4*DW-1:0] v_in,
    input  wire signed [SW-1:0] scalar,
    input  wire [5:0] shift, 
    output reg  [4*DW-1:0] v_out
);
    wire signed [DW-1:0] v0, v1, v2, v3;
    assign {v3, v2, v1, v0} = v_in;
    reg signed [DW+SW-1:0] m0, m1, m2, m3;
    
    // Gi?i h?n cho s? signed 24-bit
    localparam signed [DW-1:0] MAX_POS = 24'h7FFFFF;
    localparam signed [DW-1:0] MAX_NEG = 24'h800000;

    always @(posedge clk) begin
        // Stage 1: Nhân
        m0 <= v0 * scalar;
        m1 <= v1 * scalar;
        m2 <= v2 * scalar;
        m3 <= v3 * scalar;

        // Stage 2: D?ch bit + Bão hòa (Saturation logic)
        v_out[0*DW +: DW] <= saturate(m0 >>> shift);
        v_out[1*DW +: DW] <= saturate(m1 >>> shift);
        v_out[2*DW +: DW] <= saturate(m2 >>> shift);
        v_out[3*DW +: DW] <= saturate(m3 >>> shift);
    end

    // Hàm n?i b? ?? bão hòa s?
    function [DW-1:0] saturate(input signed [DW+SW-1:0] val);
        if (val > MAX_POS) saturate = MAX_POS;
        else if (val < MAX_NEG) saturate = MAX_NEG;
        else saturate = val[DW-1:0];
    endfunction

endmodule

