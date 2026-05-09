`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=   Module: final_back_sub                                                          =
=   Description: Performs Back Substitution to solve the system Rx = v.             =
=                Supports flexible K_MAX atoms and Q-format fixed-point math.       =
=                                                                                   =
=====================================================================================
*/

module final_back_sub #
(
    // --- System Parameters ---
    parameter                               DW        = 24                          , // Original data width (Q11.13)
    parameter                               K_MAX     = 16                          , // Maximum atoms (K)
    parameter                               VW        = 48                          , // Vector v element width (Qxx.26)
    
    // --- Fixed-point Q-format Parameters ---
    parameter                               FW_DATA   = 13                          , // Fractional bits of data
    parameter                               FW_ISR    = 22                          , // Fractional bits of ISR result

    // --- Address and Index Parameters ---
    parameter                               ADDR_W_R  = 8                           , // log2(16*16) = 8-bit for R-BRAM
    parameter                               K_W       = 5                             // clog2(K_MAX) + 1 for signed safety
)
(
    input   wire                            clk                                     ,
    input   wire                            rst_n                                   ,
    input   wire                            start_bs                                ,
    
    // Flattened v_in bus: (16 * 48 = 768 bits)
    input   wire    [(K_MAX*VW)-1:0]        v_in_flat                               ,
    
    // r_bram Interface
    output  reg     [ADDR_W_R-1:0]          r_addr                                  ,
    input   wire    [DW-1:0]                r_dout                                  ,

    // Output Outstream
    output  reg     [DW-1:0]                x_hat_val                               ,
    output  reg     [K_W-2:0]               x_hat_idx                               , // index [3:0] for 16x16
    output  reg                             x_hat_valid                             ,
    output  reg                             bs_done                                 
);

    //------------------------------------------------Internal Constants----------------------------------------
    localparam                              K_STRIDE  = $clog2(K_MAX)               ; // log2(16) = 4
    localparam signed [K_W-1:0]             START_IDX = K_MAX - 1                   ; // 15 for 16x16

    // --- FSM States ---
    localparam                              IDLE      = 3'd0                        ,
                                            FETCH_R   = 3'd1                        ,
                                            WAIT_RAM  = 3'd2                        ,
                                            CALC      = 3'd3                        ,
                                            OUT_DATA  = 3'd4                        ;

    //------------------------------------------------Internal Signals------------------------------------------
    reg             [2:0]                   state                                   ;
    reg     signed  [K_W-1:0]               i_idx, j_idx                            ; 
    reg     signed  [VW-1:0]                sum_reg                                 ; 
    reg     signed  [DW-1:0]                x_hat_mem [0:K_MAX-1]                   ; 
    
    // Unpack v_in vector
    wire    signed  [VW-1:0]                v_in [0:K_MAX-1]                        ;

    genvar k;
    generate
        for (k = 0; k < K_MAX; k = k + 1) begin : unpack_v
            assign v_in[k] = $signed(v_in_flat[k*VW +: VW])                         ;
        end
    endgenerate

    //------------------------------------------------Main Logic------------------------------------------------
    integer m;
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            state           <= IDLE                                                 ; 
            bs_done         <= 0                                                    ; 
            x_hat_valid     <= 0                                                    ;
            r_addr          <= 0                                                    ; 
            sum_reg         <= 0                                                    ; 
            i_idx           <= 0                                                    ; 
            j_idx           <= 0                                                    ;
            x_hat_val       <= 0                                                    ; 
            x_hat_idx       <= 0                                                    ;
            for (m = 0; m < K_MAX; m = m + 1) x_hat_mem[m] <= {DW{1'b0}}             ;
        end 
        else 
        begin
            case (state)
                IDLE: begin
                    bs_done     <= 1'b0                                             ; 
                    x_hat_valid <= 1'b0                                             ;
                    if (start_bs) begin
                        state       <= FETCH_R                                      ;
                        i_idx       <= START_IDX                                    ; 
                        j_idx       <= START_IDX                                    ; 
                        sum_reg     <= {VW{1'b0}}                                   ;
                    end
                end

                FETCH_R: begin
                    // Address calculation: r_addr = (j * 16) + i
                    r_addr <= (j_idx << K_STRIDE) + i_idx                           ;
                    state  <= WAIT_RAM                                              ;
                end

                WAIT_RAM: state <= CALC                                             ;

                CALC: begin
                    if (j_idx > i_idx) begin
                        // sum += R[i,j] * x[j]. Shift by FW_DATA (13)
                        sum_reg <= sum_reg + (($signed(r_dout) * $signed(x_hat_mem[j_idx])) >>> FW_DATA);
                        j_idx   <= j_idx - 1                                        ;
                        state   <= FETCH_R                                          ;
                    end 
                    else begin
                        // Solve for x[i]: x[i] = (v[i] - sum) * ISR[i]
                        // Note: r_dout at this point is the ISR (Inverse Square Root) of the diagonal
                        x_hat_mem[i_idx] <= (($signed(v_in[i_idx] >>> FW_DATA) - $signed(sum_reg[DW+FW_DATA-1 : 0])) * $signed(r_dout)) >>> FW_ISR;
                        
                        if (i_idx == 0) begin
                            state <= OUT_DATA                                       ;
                            i_idx <= 0                                              ;
                        end 
                        else begin
                            i_idx   <= i_idx - 1                                    ;
                            j_idx   <= START_IDX                                    ;
                            sum_reg <= {VW{1'b0}}                                   ;
                            state   <= FETCH_R                                      ;
                        end
                    end
                end

                OUT_DATA: begin
                    x_hat_valid <= 1'b1                                             ;
                    x_hat_idx   <= i_idx[K_W-2:0]                                   ; // Index [3:0] for 16x16
                    x_hat_val   <= x_hat_mem[i_idx]                                 ;
                    if (i_idx == START_IDX) begin
                        bs_done <= 1'b1                                             ;
                        state   <= IDLE                                             ;
                    end 
                    else i_idx  <= i_idx + 1                                        ;
                end

                default: state <= IDLE                                              ;
            endcase
        end
    end

endmodule