`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=====================================================================================
*/

module atom_selection_top
#(
    parameter                               NUM_MAC      = 4                                ,
    parameter                               DW           = 24                               ,
    parameter                               ADDR_W       = 12                               ,
    parameter                               ROW_W        = 6                                ,
    parameter                               COL_W        = 8                                ,
    parameter                               ROW_N        = 4                                ,
    parameter                               DOT_W        = 56                               ,
    parameter                               MAX_I        = 16                               ,
    parameter                               HIST_BIT_VLD = 1                                ,
    parameter                               HIST_W       = COL_W + HIST_BIT_VLD             ,
    parameter                               I_W          = $clog2(MAX_I) + 1                
)
(
    input                                   clk                                             ,
    input                                   rst_n                                           ,
    input                                   start                                           ,

    input           [COL_W - 1:0]           N_cols                                          ,
    input           [ROW_W - 1:0]           M_rows                                          ,

    output  wire    [ADDR_W - 1:0]          phi_addr                                        ,
    input   wire    [(NUM_MAC*DW) - 1:0]    phi_data                                        ,

    output  wire    [ROW_W - 1:0]           r_addr                                          ,
    input   wire    [(NUM_MAC*DW) - 1:0]    r_data                                          ,

    input   wire    [I_W - 1:0]             current_i                                       ,
    input   wire    [MAX_I*HIST_W - 1:0]    lambda_history                                  ,

    output  wire    [COL_W - 1:0]           lambda_out                                      ,
    output  wire                            atom_done                                       
);

    //------------------------------------------------Internal Signals------------------------------------------
    wire            [DOT_W - 1:0]           w_dot_result                                    ;
    wire            [COL_W - 1:0]           w_current_col                                   ;
    wire            [ROW_W - 1:0]           w_row_cnt_unused                                ;
    wire                                    w_col_done                                      ;
    wire                                    w_all_done                                      ;

    //------------------------------------------------Parallel Dot Product--------------------------------------
    dot_product_4mac #(
        .NUM_MAC                            (NUM_MAC)                                       ,
        .ADDR_W                             (ADDR_W)                                        ,
        .ROW_W                              (ROW_W)                                         ,
        .COL_W                              (COL_W)                                         ,
        .ROW_N                              (ROW_N)                                         ,
        .DW                                 (DW)                                            ,
        .ACC_W                              (DOT_W)                                         ,
        .OUT_W                              (DOT_W)                                         
    ) u_parallel_mac (
        .clk                                (clk)                                           ,
        .rst_n                              (rst_n)                                         ,
        .start_a                            (start)                                         ,
        .N_cols                             (N_cols)                                        ,
        .M_rows                             (M_rows)                                        ,
        .phi_addr                           (phi_addr)                                      ,
        .phi_data                           (phi_data)                                      ,
        .r_addr                             (r_addr)                                        ,
        .r_data                             (r_data)                                        ,
        .dot_result                         (w_dot_result)                                  ,
        .current_col_idx                    (w_current_col)                                 ,
        .row_cnt_out                        (w_row_cnt_unused)                              ,
        .col_done                           (w_col_done)                                    ,
        .all_done                           (w_all_done)                                    
    );

    //------------------------------------------------Finding Max Logic-----------------------------------------
    finding_max #(
        .DOT_W                              (DOT_W)                                         ,
        .COL_W                              (COL_W)                                         ,
        .MAX_I                              (MAX_I)                                         ,
        .HIST_W                             (HIST_W)                                        ,
        .I_W                                (I_W)                                           
    ) u_comparator_max (
        .clk                                (clk)                                           ,
        .rst_n                              (rst_n)                                         ,
        .start_search                       (start)                                         ,
        .dot_result                         (w_dot_result)                                  ,
        .current_col_idx                    (w_current_col)                                 ,
        .col_done                           (w_col_done)                                    ,
        .all_done_in                        (w_all_done)                                    ,
        .current_i                          (current_i)                                     ,
        .lambda_history                     (lambda_history)                                ,
        .lambda                             (lambda_out)                                    ,
        .finding_done                       (atom_done)                                     
    );

endmodule