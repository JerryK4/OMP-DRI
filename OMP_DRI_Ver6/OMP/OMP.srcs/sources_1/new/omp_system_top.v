`timescale 1ns / 1ps

module omp_system_top #
(
    parameter DW         = 24,
    parameter ADDR_W_PHI = 12,
    parameter ROW_W      = 6,
    parameter COL_W      = 8,
    parameter ADDR_W_Q   = 8,
    parameter DOT_W      = 56,
    parameter MAX_I      = 16,
    parameter HIST_W     = 9
)
(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start_system,
    
    // Tham s? c?u hình
    input  wire [COL_W-1:0]      N_cols,
    input  wire [ROW_W-1:0]      M_rows,
    input  wire [4:0]            K_sparsity,

    // Giao ti?p cho CPU n?p vector Y
    input  wire                  y_we_cpu,
    input  wire [3:0]            y_addr_cpu,
    input  wire [95:0]           y_din_cpu,

    // Output Data cho ph?n hi?n th? màn hình
    output wire [23:0]           x_hat_val,   // ?? sáng c?a pixel
    output wire [3:0]            x_hat_idx,   // Index th? t? (0 -> 15)
    output wire                  x_hat_valid, // Xung báo data h?p l?
    
    // Báo hi?u xong toàn b?
    output wire                  system_done,
    output wire [MAX_I*COL_W-1:0] lambda_array_out // Danh sách 16 t?a ?? (X,Y)
);

    // =========================================================================
    // 1. KHAI BÁO DÂY CHIA S? BRAM (BRAM INTERCONNECT)
    // =========================================================================
    wire [3:0]          est_y_addr_b;
    wire[95:0]         est_y_dout_b;

    wire [ADDR_W_Q-1:0] est_q_addr_b;
    wire [95:0]         est_q_dout_b;

    wire [7:0]          est_r_addr_b;
    wire[23:0]         est_r_dout_b;

    // C? báo hi?u cho phép Final Est giành quy?n MUX BRAM
    wire is_est_running;

    // =========================================================================
    // 2. INSTANTIATE 2 B? NÃO TOÁN H?C
    // =========================================================================
    wire core_start, core_done;
    wire est_start,  est_done;

    omp_core_engine #(
        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ROW_W(ROW_W), .COL_W(COL_W),
        .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W), .MAX_I(MAX_I), .HIST_W(HIST_W)
    ) u_omp_core (
        .clk(clk), .rst_n(rst_n), .start_omp(core_start),
        .N_cols(N_cols), .M_rows(M_rows), .K_sparsity(K_sparsity),
        
        // Giao ti?p CPU
        .y_we_cpu(y_we_cpu), .y_addr_cpu(y_addr_cpu), .y_din_cpu(y_din_cpu),
        
        // Giao ti?p MUX v?i Final Estimation
        .est_running_flag(is_est_running),
        .est_y_addr_b(est_y_addr_b), .est_y_dout_b(est_y_dout_b),
        .est_q_addr_b(est_q_addr_b), .est_q_dout_b(est_q_dout_b),
        .est_r_addr_b(est_r_addr_b), .est_r_dout_b(est_r_dout_b),
        
        // Output
        .omp_done(core_done), .lambda_array_out(lambda_array_out)
    );

    final_estimation_top #(.DW(DW)) u_final_est (
        .clk(clk), .rst_n(rst_n), .start_est(est_start),
        
        // N?i th?ng cáp vào OMP Core
        .y_addr(est_y_addr_b), .y_dout(est_y_dout_b),
        .q_addr(est_q_addr_b), .q_dout(est_q_dout_b),
        .r_addr(est_r_addr_b), .r_dout(est_r_dout_b), 
        
        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid), .done_all(est_done)
    );

    // =========================================================================
    // 3. SYSTEM FSM (NH?C TR??NG T?I CAO)
    // =========================================================================
    localparam SYS_IDLE     = 2'd0,
               SYS_RUN_CORE = 2'd1, // Ch?y OMP Core (Tìm 16 Lambda, t?o Q, R)
               SYS_RUN_EST  = 2'd2, // Ch?y Final Est (Gi?i ph??ng trình Rx = Q'y)
               SYS_DONE     = 2'd3;

    reg [1:0] sys_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sys_state  <= SYS_IDLE;
        end else begin
            case (sys_state)
                SYS_IDLE: begin
                    if (start_system) sys_state <= SYS_RUN_CORE;
                end
                
                SYS_RUN_CORE: begin
                    if (core_done) sys_state <= SYS_RUN_EST;
                end

                SYS_RUN_EST: begin
                    if (est_done) sys_state <= SYS_DONE;
                end

                SYS_DONE: begin
                    sys_state <= SYS_IDLE;
                end
            endcase
        end
    end

    // Gán l?nh Logic T? h?p
    assign core_start     = (sys_state == SYS_IDLE && start_system);
    assign est_start      = (sys_state == SYS_RUN_CORE && core_done);
    assign is_est_running = (sys_state == SYS_RUN_EST);
    assign system_done    = (sys_state == SYS_DONE);

endmodule