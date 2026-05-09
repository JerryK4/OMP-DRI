`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=   Module: omp_system_top                                                          =
=   Description: Top-level system for Orthogonal Matching Pursuit (OMP).            =
=                Orchestrates the OMP Core Engine and Final Estimation block        =
=                using a system-level Finite State Machine.                         =
=                                                                                   =
=====================================================================================
*/

module omp_system_top #
(
    parameter                               NUM_MAC    = 4                          ,
    parameter                               DW         = 24                         ,
    parameter                               NUM_K      = 16                         ,
    parameter                               ADDR_W_PHI = 12                         , // 4096 addresses
    parameter                               ADDR_W_Y   = 4                          ,
    parameter                               ADDR_W_R   = 8                          , 
    parameter                               ROW_W      = 6                          ,
    parameter                               COL_W      = 8                          ,
    parameter                               ADDR_W_Q   = 8                          ,
    parameter                               DOT_W      = 56                         ,
    parameter                               MAX_I      = 16                         ,
    parameter                               HIST_W     = 9                          
)
(
    input   wire                            clk                                     ,
    input   wire                            rst_n                                   ,
    input   wire                            start_system                            ,
    
    // Configuration parameters from CPU
    input   wire    [COL_W-1:0]             N_cols                                  ,
    input   wire    [ROW_W-1:0]             M_rows                                  ,
    input   wire    [$clog2(NUM_K):0]       K_sparsity                              ,

    // DMA Interface: Loading vector Y
    input   wire                            y_we_cpu                                ,
    input   wire    [ADDR_W_Y-1:0]          y_addr_cpu                              ,
    input   wire    [(NUM_MAC*DW)-1:0]      y_din_cpu                               ,

    // DMA Interface: Loading Matrix PHI
    input   wire                            phi_we_cpu                              ,
    input   wire    [ADDR_W_PHI-1:0]        phi_addr_cpu                            ,
    input   wire    [(NUM_MAC*DW)-1:0]      phi_din_cpu                             ,

    // System Output: Final x_hat results
    output  wire    [DW-1:0]                x_hat_val                               , // Pixel intensity
    output  wire    [$clog2(NUM_K)-1:0]     x_hat_idx                               , // Sequence index (0 -> K-1)
    output  wire                            x_hat_valid                             , // Valid data pulse
    
    // Status signals
    output  wire                            system_done                             ,
    output  wire    [MAX_I*COL_W-1:0]       lambda_array_out                          // Coordinates list
);

    //------------------------------------------------1. BRAM MUX INTERCONNECT----------------------------------
    // These signals allow Final Estimation to access BRAMs inside OMP Core
    wire            [ADDR_W_Y-1:0]          est_y_addr                              ;
    wire            [(NUM_MAC*DW)-1:0]      est_y_dout                              ;

    wire            [ADDR_W_Q-1:0]          est_q_addr                              ;
    wire            [(NUM_MAC*DW)-1:0]      est_q_dout                              ;

    wire            [ADDR_W_R-1:0]          est_r_addr                              ;
    wire            [DW-1:0]                est_r_dout                              ;

    wire                                    is_est_running                          ; // MUX control flag

    //------------------------------------------------2. SUB-MODULE INSTANTIATION-------------------------------
    wire                                    core_start, core_done                   ;
    wire                                    est_start,  est_done                    ;

    // --- CORE ENGINE: Atom Search & Orthogonalization ---
    omp_core_engine #(
        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ROW_W(ROW_W), .COL_W(COL_W),
        .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W), .MAX_I(MAX_I), .HIST_W(HIST_W)
    ) u_omp_core (
        .clk                                (clk)                                   , 
        .rst_n                              (rst_n)                                 , 
        .start_omp                          (core_start)                            ,
        .N_cols                             (N_cols)                                , 
        .M_rows                             (M_rows)                                , 
        .K_sparsity                         (K_sparsity)                            ,
        
        .y_we_cpu                           (y_we_cpu)                              , 
        .y_addr_cpu                         (y_addr_cpu)                            , 
        .y_din_cpu                          (y_din_cpu)                             ,
        
        .phi_we_cpu                         (phi_we_cpu)                            , 
        .phi_addr_cpu                       (phi_addr_cpu)                          , 
        .phi_din_cpu                        (phi_din_cpu)                           ,
        
        // Port sharing/MUX for Final Estimation
        .est_running_flag                   (is_est_running)                        ,
        .est_y_addr_b                       (est_y_addr)                            , 
        .est_y_dout_b                       (est_y_dout)                            ,
        .est_q_addr_b                       (est_q_addr)                            , 
        .est_q_dout_b                       (est_q_dout)                            ,
        .est_r_addr_b                       (est_r_addr)                            , 
        .est_r_dout_b                       (est_r_dout)                            ,
        
        .omp_done                           (core_done)                             , 
        .lambda_array_out                   (lambda_array_out)
    );

    // --- FINAL ESTIMATION: Back-Substitution Solver ---
    final_estimation_top #(
        .DW(DW)
    ) u_final_est (
        .clk                                (clk)                                   , 
        .rst_n                              (rst_n)                                 , 
        .start_est                          (est_start)                             ,
        
        .y_addr                             (est_y_addr)                            , 
        .y_dout                             (est_y_dout)                            ,
        .q_addr                             (est_q_addr)                            , 
        .q_dout                             (est_q_dout)                            ,
        .r_addr                             (est_r_addr)                            , 
        .r_dout                             (est_r_dout)                            , 
        
        .x_hat_val                          (x_hat_val)                             , 
        .x_hat_idx                          (x_hat_idx)                             ,
        .x_hat_valid                        (x_hat_valid)                           , 
        .done_all                           (est_done)
    );

    //------------------------------------------------3. SYSTEM FSM LOGIC---------------------------------------
    localparam                              SYS_IDLE     = 2'd0                     ,
                                            SYS_RUN_CORE = 2'd1                     , // Step 1: OMP Core Search
                                            SYS_RUN_EST  = 2'd2                     , // Step 2: Final Solve
                                            SYS_DONE     = 2'd3                     ;

    reg             [1:0]                   sys_state                               ;

    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            sys_state <= SYS_IDLE                                                   ;
        end 
        else 
        begin
            case (sys_state)
                SYS_IDLE: begin
                    if (start_system) sys_state <= SYS_RUN_CORE                     ;
                end
                
                SYS_RUN_CORE: begin
                    if (core_done) sys_state <= SYS_RUN_EST                         ;
                end

                SYS_RUN_EST: begin
                    if (est_done) sys_state <= SYS_DONE                             ;
                end

                SYS_DONE: begin
                    sys_state <= SYS_IDLE                                           ;
                end
                
                default: sys_state <= SYS_IDLE                                      ;
            endcase
        end
    end

    // Combinational Logic for sub-system control
    assign core_start     = (sys_state == SYS_IDLE && start_system)                 ;
    assign est_start      = (sys_state == SYS_RUN_CORE && core_done)                ;
    assign is_est_running = (sys_state == SYS_RUN_EST)                             ;
    assign system_done    = (sys_state == SYS_DONE)                                 ;

endmodule