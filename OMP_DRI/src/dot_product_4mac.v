`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=====================================================================================
*/

module dot_product_4mac
#(
    parameter                               NUM_MAC = 4                                     ,
    parameter                               ADDR_W  = 12                                    ,
    parameter                               COL_W   = 8                                     ,
    parameter                               ROW_W   = 6                                     ,
    parameter                               ROW_N   = 4                                     ,
    parameter                               DW      = 24                                    ,
    parameter                               ACC_W   = 56                                    ,
    parameter                               OUT_W   = 56                                    
)
(
    input                                   clk                                             ,
    input                                   rst_n                                           ,
    input                                   start_a                                         ,
    input           [COL_W - 1:0]           N_cols                                          ,
    input           [ROW_W - 1:0]           M_rows                                          ,
    input           [(NUM_MAC*DW) - 1:0]    phi_data                                        ,
    input           [(NUM_MAC*DW) - 1:0]    r_data                                          ,
    
    output  reg     [ADDR_W - 1:0]          phi_addr                                        ,
    output  reg     [ROW_W - 1:0]           r_addr                                          ,
    output  reg     [OUT_W - 1:0]           dot_result                                      ,
    output  reg     [COL_W - 1:0]           current_col_idx                                 ,
    output  wire    [ROW_W - 1:0]           row_cnt_out                                     ,
    output  reg                             col_done                                        ,
    output  reg                             all_done                                        
);

    reg             [1:0]                   state                                           ;
    reg             [ROW_W - 1:0]           row_ptr                                         ;
    reg             [COL_W - 1:0]           col_ptr                                         ;
    reg     signed  [ACC_W - 1:0]           acc                                             ;
    reg                                     pipe_vld                                        ;

    wire    signed  [DW - 1:0]              p [0:NUM_MAC - 1]                               ;
    wire    signed  [DW - 1:0]              r [0:NUM_MAC - 1]                               ;

    localparam                              IDLE     = 2'd0                                 ;
    localparam                              RUN_COL  = 2'd1                                 ;
    localparam                              HOLD_RES = 2'd2                                 ;
    localparam                              FINISH   = 2'd3                                 ;

    //------------------------------------------------Data Unpack-----------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_MAC; g = g + 1) begin : unpack_loop
            assign p[g] = phi_data[g*DW +: DW]                                              ;
            assign r[g] = r_data[g*DW +: DW]                                                ;
        end
    endgenerate

    assign row_cnt_out = row_ptr                                                            ;

    //------------------------------------------------Main Logic------------------------------------------------
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            state           <= IDLE                                                         ;
            phi_addr        <= 0                                                            ;
            r_addr          <= 0                                                            ;
            acc             <= 0                                                            ;
            pipe_vld        <= 0                                                            ;
            col_done        <= 0                                                            ;
            all_done        <= 0                                                            ;
            row_ptr         <= 0                                                            ;
            col_ptr         <= 0                                                            ;
            current_col_idx <= 0                                                            ;
            dot_result      <= 0                                                            ;
        end 
        else 
        begin
            col_done        <= 0                                                            ;

            case (state)
                IDLE: begin
                    all_done <= 0                                                           ;
                    if (start_a) begin
                        state    <= RUN_COL                                                 ;
                        col_ptr  <= 0                                                       ;
                        row_ptr  <= 0                                                       ;
                        acc      <= 0                                                       ;
                        pipe_vld <= 0                                                       ;
                        phi_addr <= (0 << ROW_N)                                            ;
                        r_addr   <= 0                                                       ;
                    end
                end

                RUN_COL: begin
                    // 1. Address Phase
                    if (row_ptr < M_rows) begin
                        row_ptr  <= row_ptr + 1'b1                                          ;
                        phi_addr <= (col_ptr << ROW_N) + (row_ptr + 1'b1)                   ;
                        r_addr   <= row_ptr + 1'b1                                          ;
                        pipe_vld <= 1'b1                                                    ;
                    end 
                    else begin
                        pipe_vld <= 1'b0                                                    ;
                    end

                    // 2. Data Phase
                    if (pipe_vld || (row_ptr > 0 && row_ptr <= M_rows)) begin
                        acc <= acc + ($signed(p[0]) * $signed(r[0])) 
                                   + ($signed(p[1]) * $signed(r[1])) 
                                   + ($signed(p[2]) * $signed(r[2])) 
                                   + ($signed(p[3]) * $signed(r[3]))                        ;
                    end

                    // 3. Check End of Column
                    if (!pipe_vld && row_ptr == M_rows) begin
                        state <= HOLD_RES                                                   ;
                    end
                end

                HOLD_RES: begin
                    dot_result      <= acc                                                  ;
                    current_col_idx <= col_ptr                                              ;
                    col_done        <= 1'b1                                                 ;
                    
                    if (col_ptr == N_cols) begin
                        state <= FINISH                                                     ;
                    end 
                    else begin
                        col_ptr  <= col_ptr + 1'b1                                          ;
                        row_ptr  <= 0                                                       ;
                        acc      <= 0                                                       ;
                        pipe_vld <= 0                                                       ;
                        phi_addr <= ((col_ptr + 1'b1) << ROW_N)                             ;
                        r_addr   <= 0                                                       ;
                        state    <= RUN_COL                                                 ;
                    end
                end

                FINISH: begin
                    all_done <= 1'b1                                                        ;
                    state    <= IDLE                                                        ;
                end

                default: state <= IDLE                                                      ;
            endcase
        end
    end

endmodule