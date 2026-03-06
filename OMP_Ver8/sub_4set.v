//`timescale 1ns / 1ps

//module sub_4set #(
//    parameter DW = 24
//)(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire [4*DW-1:0] a_vec, // Vector b? tr? {a3, a2, a1, a0}
//    input  wire [4*DW-1:0] b_vec, // Vector tr?    {b3, b2, b1, b0}
//    output reg  [4*DW-1:0] res_vec
//);

//    // Unpack
//    wire signed [DW-1:0] a0, a1, a2, a3;
//    wire signed [DW-1:0] b0, b1, b2, b3;
//    assign {a3, a2, a1, a0} = a_vec;
//    assign {b3, b2, b1, b0} = b_vec;

//    // Phép tr? song song có Pipeline
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            res_vec <= 0;
//        end else begin
//            res_vec[0*DW +: DW] <= a0 - b0;
//            res_vec[1*DW +: DW] <= a1 - b1;
//            res_vec[2*DW +: DW] <= a2 - b2;
//            res_vec[3*DW +: DW] <= a3 - b3;
//        end
//    end
//endmodule

`timescale 1ns / 1ps

module sub_4set #
(
    // --- S?a: Tham s? hóa ?? r?ng và s? l??ng b? tr? ---
    parameter DW      = 24,    // ?? r?ng d? li?u
    parameter NUM_SET = 4      // S?a: S? l??ng ph?n t? tr? song song (m?c ??nh là 4)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [(NUM_SET*DW)-1:0] a_vec, // S?a: Vector b? tr? (Dùng NUM_SET)
    input  wire [(NUM_SET*DW)-1:0] b_vec, // S?a: Vector tr?    (Dùng NUM_SET)
    output reg  [(NUM_SET*DW)-1:0] res_vec // S?a: K?t qu? (Dùng NUM_SET)
);

    // --- S?a: Unpack d? li?u s? d?ng m?ng và vòng l?p generate ---
    wire signed [DW-1:0] a [0:NUM_SET-1];
    wire signed [DW-1:0] b [0:NUM_SET-1];
    
    genvar i;
    generate
        for (i = 0; i < NUM_SET; i = i + 1) begin : unpack_vecs
            assign a[i] = a_vec[i*DW +: DW];
            assign b[i] = b_vec[i*DW +: DW];
        end
    endgenerate

    // --- Phép tr? song song có Pipeline: Gi? nguyên logic g?c ---
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            res_vec <= 0;
        end else begin
            // S?a: S? d?ng vòng l?p for ?? th?c hi?n phép tr? song song d?a trên NUM_SET
            for (j = 0; j < NUM_SET; j = j + 1) begin
                res_vec[j*DW +: DW] <= a[j] - b[j];
            end
        end
    end
endmodule