`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=   Module: final_v_calc                                                            =
=   Description: Computes final vector v = Q^T * y by reusing the MAC module        =
=                                                                                   =
=====================================================================================
*/

module final_v_calc #
(
    parameter                               NUM_MAC  = 4                            ,
    parameter                               DW       = 24                           , // Q10.13 format
    parameter                               ROW_N    = 4                            ,
    parameter                               ADDR_W_Q = 8                            , // 256 rows
    parameter                               ADDR_W_Y = 4                            ,
    parameter                               DOT_W    = 56                           , // Accumulator width
    parameter                               VW       = 48                           ,
    parameter                               NUM_K    = 16                             // Number of atoms (K=16)
)
(
    input   wire                            clk                                     ,
    input   wire                            rst_n                                   ,
    input   wire                            start_v                                 ,
    
    // y_bram Interface (Read Only)
    output  wire    [ADDR_W_Y-1:0]          y_addr                                  ,
    input   wire    [(NUM_MAC*DW)-1:0]      y_dout                                  ,

    // q_bram Interface (Read Only)
    output  wire    [ADDR_W_Q-1:0]          q_addr                                  ,
    input   wire    [(NUM_MAC*DW)-1:0]      q_dout                                  ,

    // Output: Flattened vector v (16 elements * 48 bits = 768 bits)
    output  reg     [(NUM_K*VW)-1:0]        v_result_flat                           ,
    output  reg                             v_done                                  
);

    //------------------------------------------------Internal Signals------------------------------------------
    localparam                              IDLE    = 2'd0                          ;
    localparam                              CALC    = 2'd1                          ;
    localparam                              DONE_ST = 2'd2                          ;

    reg             [1:0]                   state                                   ;
    reg             [$clog2(NUM_K)-1:0]     i_cnt                                   ; // Column index (0..15)

    wire                                    mac_all_done                            ;
    wire            [DOT_W-1:0]             mac_val                                 ;
    wire            [ADDR_W_Y-1:0]          mac_row_cnt                             ;
    reg                                     start_mac_reg                           ;

    //------------------------------------------------1. REUSE MAC UNIT-----------------------------------------
    dot_product_4mac #(
        .DW                                 (24)                                    , 
        .OUT_W                              (56)                                    , 
        .ROW_W                              (4)
    ) u_mac_v (
        .clk                                (clk)                                   , 
        .rst_n                              (rst_n)                                 , 
        .start_a                            (start_mac_reg)                         ,
        .N_cols                             (0)                                     , // Calculate 1 col per call
        .M_rows                             (NUM_K-1)                               ,
        .phi_data                           (q_dout)                                , 
        .r_data                             (y_dout)                                ,
        .dot_result                         (mac_val)                               , 
        .all_done                           (mac_all_done)                          ,
        .row_cnt_out                        (mac_row_cnt)                           ,
        .phi_addr                           ()                                      , 
        .r_addr                             ()
    );

    // Address Control Logic
    // q_addr: points to column i_cnt, row mac_row_cnt
    assign q_addr = (i_cnt << ROW_N) + mac_row_cnt                                  ;
    // y_addr: points to row mac_row_cnt of observation vector y
    assign y_addr = mac_row_cnt                                                     ;

    //------------------------------------------------2. MASTER FSM LOGIC---------------------------------------
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            state           <= IDLE                                                 ;
            v_done          <= 0                                                    ;
            i_cnt           <= 0                                                    ;
            v_result_flat   <= 0                                                    ;
            start_mac_reg   <= 0                                                    ;
        end 
        else 
        begin
            case (state)
                IDLE: begin
                    v_done <= 1'b0                                                  ;
                    if (start_v) begin
                        state           <= CALC                                     ;
                        i_cnt           <= 0                                        ;
                        start_mac_reg   <= 1'b1                                     ; // Trigger MAC first time
                    end
                end

                CALC: begin
                    start_mac_reg <= 1'b0                                           ; // Clear start pulse

                    if (mac_all_done) begin
                        // Map result into the flattened output vector
                        v_result_flat[i_cnt * VW +: VW] <= mac_val[VW-1:0]          ;

                        if (i_cnt == NUM_K-1) begin
                            state <= DONE_ST                                        ;
                        end else begin
                            i_cnt           <= i_cnt + 1'b1                         ;
                            start_mac_reg   <= 1'b1                                 ; // Trigger next column
                            state           <= CALC                                 ;
                        end
                    end
                end

                DONE_ST: begin
                    v_done <= 1'b1                                                  ;
                    state  <= IDLE                                                  ;
                end

                default: state <= IDLE                                              ;
            endcase
        end
    end

endmodule