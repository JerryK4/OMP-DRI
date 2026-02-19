`timescale 1ns / 1ps

module sub_4set #(
    parameter DW = 24
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [4*DW-1:0] a_vec, // Vector b? tr? {a3, a2, a1, a0}
    input  wire [4*DW-1:0] b_vec, // Vector tr?    {b3, b2, b1, b0}
    output reg  [4*DW-1:0] res_vec
);

    // Unpack
    wire signed [DW-1:0] a0, a1, a2, a3;
    wire signed [DW-1:0] b0, b1, b2, b3;
    assign {a3, a2, a1, a0} = a_vec;
    assign {b3, b2, b1, b0} = b_vec;

    // Phép tr? song song có Pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            res_vec <= 0;
        end else begin
            res_vec[0*DW +: DW] <= a0 - b0;
            res_vec[1*DW +: DW] <= a1 - b1;
            res_vec[2*DW +: DW] <= a2 - b2;
            res_vec[3*DW +: DW] <= a3 - b3;
        end
    end
endmodule