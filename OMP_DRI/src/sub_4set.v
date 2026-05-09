`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=====================================================================================
*/

module sub_4set
#(
    parameter                               DW      = 24                                    ,
    parameter                               NUM_SET = 4                                     
)
(
    input                                   clk                                             ,
    input                                   rst_n                                           ,
    input           [(NUM_SET*DW) - 1:0]    a_vec                                           ,
    input           [(NUM_SET*DW) - 1:0]    b_vec                                           ,

    output  reg     [(NUM_SET*DW) - 1:0]    res_vec                                         
);

    //------------------------------------------------Internal Signals------------------------------------------
    wire    signed  [DW - 1:0]              a [0:NUM_SET - 1]                               ;
    wire    signed  [DW - 1:0]              b [0:NUM_SET - 1]                               ;

    //------------------------------------------------Data Unpack-----------------------------------------------
    genvar i;
    generate
        for (i = 0; i < NUM_SET; i = i + 1) begin : unpack_vecs
            assign a[i] = a_vec[i*DW +: DW]                                                 ;
            assign b[i] = b_vec[i*DW +: DW]                                                 ;
        end
    endgenerate

    //------------------------------------------------Parallel Subtraction--------------------------------------
    integer j;
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            res_vec <= 0                                                                    ;
        end 
        else 
        begin
            for (j = 0; j < NUM_SET; j = j + 1) 
            begin
                res_vec[j*DW +: DW] <= a[j] - b[j]                                          ;
            end
        end
    end

endmodule