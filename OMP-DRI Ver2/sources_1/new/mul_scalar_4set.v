//`timescale 1ns / 1ps

//module mul_scalar_4set #(
//    parameter DW = 24,
//    parameter SW = 24,     // Scalar Width
//    parameter SHIFT = 13   // M?c ??nh d?ch 13 bit cho Q10.13
//)(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire [4*DW-1:0] v_in,   // Vector ??u vào {v3, v2, v1, v0}
//    input  wire signed [SW-1:0] scalar, // H?ng s? nhân chung
//    output reg  [4*DW-1:0] v_out   // Vector ??u ra sau khi d?ch bit
//);

//    // Unpack
//    wire signed [DW-1:0] v0, v1, v2, v3;
//    assign {v3, v2, v1, v0} = v_in;

//    // K?t qu? nhân trung gian (DW + SW bit)
//    reg signed [DW+SW-1:0] m0, m1, m2, m3;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            m0 <= 0; m1 <= 0; m2 <= 0; m3 <= 0;
//            v_out <= 0;
//        end else begin
//            // Stage 1: Nhân (Vivado s? map vào DSP48E1)
//            m0 <= v0 * scalar;
//            m1 <= v1 * scalar;
//            m2 <= v2 * scalar;
//            m3 <= v3 * scalar;

//            // Stage 2: D?ch bit ?? gi? nguyên ??nh d?ng Q-format
//            // L?y DW bit t? v? trí SHIFT tr? lên
//            v_out[0*DW +: DW] <= m0[SHIFT +: DW];
//            v_out[1*DW +: DW] <= m1[SHIFT +: DW];
//            v_out[2*DW +: DW] <= m2[SHIFT +: DW];
//            v_out[3*DW +: DW] <= m3[SHIFT +: DW];
//        end
//    end
//endmodule

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