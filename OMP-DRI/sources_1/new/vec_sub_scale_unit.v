`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 03:21:31 PM
// Design Name: 
// Module Name: vec_sub_scale_unit
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


module vec_sub_scale_unit (
    input wire signed [23:0] scalar_u, // H? s? Uji (Q10.13)
    input wire [95:0] vec_q,           // 4 ph?n t? Qj t? BRAM Q
    input wire [95:0] vec_w_old,       // 4 ph?n t? w c? t? b? ??m
    output wire [95:0] vec_w_new       // w_new = w_old - U*Q
);
    wire signed [23:0] q[0:3], w_o[0:3], w_n[0:3];
    assign {q[3], q[2], q[1], q[0]} = vec_q;
    assign {w_o[3], w_o[2], w_o[1], w_o[0]} = vec_w_old;

    genvar k;
    generate
        for (k = 0; k < 4; k = k + 1) begin: scale_logic
            wire signed [47:0] prod = scalar_u * q[k];
            // L?y bit 13 ??n 36 ?? ??a Q20.26 v? Q10.13
            assign w_n[k] = w_o[k] - prod[36:13];
        end
    endgenerate

    assign vec_w_new = {w_n[3], w_n[2], w_n[1], w_n[0]};
endmodule
