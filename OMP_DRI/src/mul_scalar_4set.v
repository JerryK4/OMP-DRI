`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=====================================================================================
*/

module mul_scalar_4set
#(
    parameter                               DW      = 24                                    ,
    parameter                               SW      = 24                                    ,
    parameter                               NUM_SET = 4                                     
)
(
    input                                   clk                                             ,
    input                                   rst_n                                           ,
    input           [(NUM_SET*DW) - 1:0]    v_in                                            ,
    input   signed  [SW - 1:0]              scalar                                          ,
    input           [5:0]                   shift                                           ,

    output  reg     [(NUM_SET*DW) - 1:0]    v_out                                           
);

    //------------------------------------------------Internal Signals------------------------------------------
    wire    signed  [DW - 1:0]              v [0:NUM_SET - 1]                               ;
    reg     signed  [DW + SW - 1:0]         m [0:NUM_SET - 1]                               ;

    localparam signed [DW - 1:0]            MAX_POS = {1'b0, {(DW - 1){1'b1}}}              ;
    localparam signed [DW - 1:0]            MAX_NEG = {1'b1, {(DW - 1){1'b0}}}              ;

    //------------------------------------------------Data Unpack-----------------------------------------------
    genvar i;
    generate
        for (i = 0; i < NUM_SET; i = i + 1) begin : unpack_v
            assign v[i] = v_in[i*DW +: DW]                                                  ;
        end
    endgenerate

    //------------------------------------------------Main Logic Pipeline---------------------------------------
    integer j;
    always @(posedge clk) 
    begin
        // Stage 1: Multiplication
        for (j = 0; j < NUM_SET; j = j + 1) 
        begin
            m[j] <= v[j] * scalar                                                           ;
        end

        // Stage 2: Bit-shift + Saturation
        for (j = 0; j < NUM_SET; j = j + 1) 
        begin
            v_out[j*DW +: DW] <= saturate(m[j] >>> shift)                                   ;
        end
    end

    //------------------------------------------------Function: Saturation--------------------------------------
    function [DW - 1:0] saturate(input signed [DW + SW - 1:0] val);
        if (val > $signed({ {(SW){1'b0}}, MAX_POS })) 
            saturate = MAX_POS;
        else if (val < $signed({ {(SW){1'b1}}, MAX_NEG })) 
            saturate = MAX_NEG;
        else 
            saturate = val[DW - 1:0];
    endfunction

endmodule