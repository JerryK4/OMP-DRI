`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 03:20:55 PM
// Design Name: 
// Module Name: mac_4_parallel
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


module mac_4_parallel (
    input wire signed [23:0] a0, a1, a2, a3,
    input wire signed [23:0] b0, b1, b2, b3,
    output wire signed [47:0] sum_out // 48-bit ?? ch?ng tràn khi c?ng 4 tích
);
    // 4 b? nhân song song (Fixed-point Q10.13 * Q10.13 = Q20.26)
    wire signed [47:0] p0 = a0 * b0;
    wire signed [47:0] p1 = a1 * b1;
    wire signed [47:0] p2 = a2 * b2;
    wire signed [47:0] p3 = a3 * b3;

    assign sum_out = p0 + p1 + p2 + p3;
endmodule
