`timescale 1ns / 1ps

/*
=====================================================================================
=                                                                                   =
=   Author: Doan Duc Manh - UET - VNU                                               =
=                                                                                   =
=   Module: tb_omp_system_top                                                       =
=   Description: Standard Testbench for OMP System (16x16 Configuration).           =
=                Verifies the complete flow from Atom Search to Final Estimation    =
=                using predefined BRAM data (.coe).                                 =
=                                                                                   =
=====================================================================================
*/

module tb_omp_system_top;

    //------------------------------------------------1. SYSTEM PARAMETERS--------------------------------------
    parameter                               CLK_PERIOD   = 10                       ; // 100MHz
    parameter                               NUM_MAC      = 4                        ; // Parallel MAC units
    parameter                               DW           = 24                       ; // Data format Q11.13
    parameter                               COL_W        = 8                        ; // N=256 -> 8 bit
    parameter                               ROW_W        = 6                        ; // M_rows -> 6 bit
    parameter                               K_W          = 5                        ; // K=16 -> 5 bit
    parameter                               ROW_N        = 4                        ; // Stride (log2(64/4)=4)
    parameter                               ADDR_W_PHI   = 12                       ;
    parameter                               ADDR_W_Q     = 12                       ;
    parameter                               ADDR_W_R     = 12                       ;
    parameter                               ADDR_W_Y     = 6                        ; // Y Address width
    parameter                               MAX_I        = 16                       ;
    parameter                               DOT_W        = 56                       ;
    parameter                               VW           = 48                       ;

    //------------------------------------------------2. INTERFACE SIGNALS--------------------------------------
    reg                                     clk                                     ;
    reg                                     rst_n                                   ;
    reg                                     start_system                            ;
    
    reg             [COL_W-1:0]             N_cols                                  ;
    reg             [ROW_W-1:0]             M_rows                                  ;
    reg             [K_W-1:0]               K_sparsity                              ;

    // CPU/DMA Ports
    reg                                     y_we_cpu                                ;
    reg             [ADDR_W_Y-1:0]          y_addr_cpu                              ;
    reg             [(NUM_MAC*DW)-1:0]      y_din_cpu                               ;
    reg                                     phi_we_cpu                              ;
    reg             [ADDR_W_PHI-1:0]        phi_addr_cpu                            ;
    reg             [(NUM_MAC*DW)-1:0]      phi_din_cpu                             ;

    // DUT Outputs
    wire            [DW-1:0]                x_hat_val                               ;
    wire            [$clog2(MAX_I)-1:0]     x_hat_idx                               ;
    wire                                    x_hat_valid                             ;
    wire                                    system_done                             ;
    wire            [MAX_I*COL_W-1:0]       lambda_array_out                        ;

    //------------------------------------------------3. DUT INSTANTIATION--------------------------------------
    omp_system_top #(
        .NUM_MAC                            (NUM_MAC)                               ,
        .DW                                 (DW)                                    ,
        .COL_W                              (COL_W)                                 ,
        .ROW_W                              (ROW_W)                                 ,
        .K_W                                (K_W)                                   ,
        .ROW_N                              (ROW_N)                                 ,
        .ADDR_W_PHI                         (ADDR_W_PHI)                            ,
        .ADDR_W_Q                           (ADDR_W_Q)                              ,
        .ADDR_W_R                           (ADDR_W_R)                              ,
        .ADDR_W_Y                           (ADDR_W_Y)                              ,
        .DOT_W                              (DOT_W)                                 ,
        .MAX_I                              (MAX_I)                                 ,
        .VW                                 (VW)
    ) dut (
        .clk                                (clk)                                   ,
        .rst_n                              (rst_n)                                 ,
        .start_system                       (start_system)                          ,
        .N_cols                             (N_cols)                                ,
        .M_rows                             (M_rows)                                ,
        .K_sparsity                         (K_sparsity)                            ,
        .y_we_cpu                           (y_we_cpu)                              ,
        .y_addr_cpu                         (y_addr_cpu)                            ,
        .y_din_cpu                          (y_din_cpu)                             ,
        .phi_we_cpu                         (phi_we_cpu)                            ,
        .phi_addr_cpu                       (phi_addr_cpu)                          ,
        .phi_din_cpu                        (phi_din_cpu)                           ,
        .x_hat_val                          (x_hat_val)                             ,
        .x_hat_idx                          (x_hat_idx)                             ,
        .x_hat_valid                        (x_hat_valid)                           ,
        .system_done                        (system_done)                           ,
        .lambda_array_out                   (lambda_array_out)
    );

    //------------------------------------------------4. CLOCK & DECODER----------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk                                          ;
    end

    // Unpack Lambda Array for easy debugging
    wire            [7:0]                   lambda_result [0:MAX_I-1]               ;
    genvar g;
    generate
        for (g = 0; g < MAX_I; g = g + 1) begin : gen_unpack
            assign lambda_result[g] = lambda_array_out[g*COL_W +: COL_W]            ;
        end
    endgenerate

    //------------------------------------------------5. LOGGER & MONITORING------------------------------------
    integer file_id;
    real val_float;
    reg [1:0] prev_sys_state;

    initial begin
        file_id = $fopen("omp_reconstruction_results.txt", "w");
        if (file_id == 0) begin
            $display("ERROR: Cannot create output log file!");
            $finish;
        end
        $fdisplay(file_id, "--- OMP RECONSTRUCTION RESULTS (PARAMETERIZED SYSTEM) ---");
        $fdisplay(file_id, "Index | Lambda | Intensity (Hex) | Intensity (Float)");
    end

    // Monitor System FSM Transitions
    always @(posedge clk) begin
        if (rst_n && dut.sys_state != prev_sys_state) begin
            case(dut.sys_state)
                2'd1: $display("\n[%0t ns] >>> STARTING: OMP Core (Atom Searching)...", $time/1000);
                2'd2: $display("[%0t ns] >>> STARTING: Final Estimation (Solving Rx=v)...", $time/1000);
                2'd3: $display("[%0t ns] >>> COMPLETED!", $time/1000);
            endcase
            prev_sys_state <= dut.sys_state;
        end
    end

    // Log results on Valid pulses
    always @(posedge clk) begin
        if (rst_n && x_hat_valid) begin
            val_float = $signed(x_hat_val) / 8192.0; 
            
            $fdisplay(file_id, "  %2d  |  %3d   |    %6x     |   %f", 
                      x_hat_idx, lambda_result[x_hat_idx], x_hat_val, val_float);
            
            $display("[%0t ns] [RESULT] Pixel %0d (Lambda %0d) = %f", 
                     $time/1000, x_hat_idx, lambda_result[x_hat_idx], val_float);
        end
    end

    //------------------------------------------------6. TEST SCENARIO------------------------------------------
    initial begin
        // Reset and Initialization
        rst_n = 0; start_system = 0; prev_sys_state = 0                             ;
        y_we_cpu = 0; y_addr_cpu = 0; y_din_cpu = 0                                 ;
        phi_we_cpu = 0; phi_addr_cpu = 0; phi_din_cpu = 0                           ;

        // Configuration for 16x16 image
        N_cols     = 8'd255; 
        M_rows     = 6'd15;  // (64 measurements / 4 MAC) - 1 = 15
        K_sparsity = 5'd16;  

        // Wait for BRAM stabilization
        #(CLK_PERIOD * 20);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("---------------------------------------------------------");
        $display("   STARTING OMP SYSTEM SIMULATION (16x16)                ");
        $display("---------------------------------------------------------");
        
        start_system = 1;
        #(CLK_PERIOD);
        start_system = 0;

        // Wait for system completion
        wait(system_done == 1'b1);
        #(CLK_PERIOD * 20);

        $fclose(file_id);
        $display("\n---------------------------------------------------------");
        $display("   SIMULATION FINISHED. CHECK 'omp_reconstruction_results.txt'");
        $display("---------------------------------------------------------");
        $finish;
    end

endmodule