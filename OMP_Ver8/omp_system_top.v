`timescale 1ns / 1ps

module omp_system_top #
(
    parameter DW         = 24,
    parameter ADDR_W_PHI = 12, // 4096 ??a ch?
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
    
    // Tham s? c?u hình OMP/DRI t? CPU
    input  wire [COL_W-1:0]      N_cols,
    input  wire [ROW_W-1:0]      M_rows,
    input  wire [4:0]            K_sparsity,

    // Giao ti?p cho DMA n?p vector Y
    input  wire                  y_we_cpu,
    input  wire [3:0]            y_addr_cpu,
    input  wire [95:0]           y_din_cpu,

    // Giao ti?p cho DMA n?p Ma tr?n PHI (?ã ??ng b?)
    input  wire                  phi_we_cpu,
    input  wire [ADDR_W_PHI-1:0] phi_addr_cpu,
    input  wire [95:0]           phi_din_cpu,

    // Output Data cho DMA/Màn hình (T? kh?i Final Estimation)
    output wire [23:0]           x_hat_val,   // C??ng ?? sáng c?a pixel
    output wire [3:0]            x_hat_idx,   // Index th? t? (0 -> K-1)
    output wire                  x_hat_valid, // Xung báo data h?p l?
    
    // Tín hi?u báo xong toàn b? h? th?ng
    output wire                  system_done,
    output wire [MAX_I*COL_W-1:0] lambda_array_out // Danh sách t?a ?? Lambda
);

    // =========================================================================
    // 1. DÂY K?T N?I MUX ?? LÕI FINAL_ESTIMATION ??C BRAM T? OMP_CORE
    // =========================================================================
    wire [3:0]          est_y_addr;
    wire[95:0]         est_y_dout;

    wire [ADDR_W_Q-1:0] est_q_addr;
    wire [95:0]         est_q_dout;

    wire[7:0]          est_r_addr;
    wire [23:0]         est_r_dout;

    // C? báo hi?u cho phép Final Est giành quy?n MUX ??c BRAM
    wire is_est_running;

    // =========================================================================
    // 2. INSTANTIATE 2 B? NÃO TÍNH TOÁN
    // =========================================================================
    wire core_start, core_done;
    wire est_start,  est_done;

    // --- LÕI 1: TÌM LAMBDA VÀ TR?C GIAO HÓA (CH?A S?N BRAM) ---
    omp_core_engine #(
        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ROW_W(ROW_W), .COL_W(COL_W),
        .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W), .MAX_I(MAX_I), .HIST_W(HIST_W)
    ) u_omp_core (
        .clk(clk), .rst_n(rst_n), .start_omp(core_start),
        .N_cols(N_cols), .M_rows(M_rows), .K_sparsity(K_sparsity),
        
        // Giao ti?p CPU/DMA n?p Y
        .y_we_cpu(y_we_cpu), .y_addr_cpu(y_addr_cpu), .y_din_cpu(y_din_cpu),
        
        // Giao ti?p CPU/DMA n?p PHI
        .phi_we_cpu(phi_we_cpu), .phi_addr_cpu(phi_addr_cpu), .phi_din_cpu(phi_din_cpu),
        
        // Cung c?p c?ng ??c BRAM (MUX) cho kh?i Final Estimation
        .est_running_flag(is_est_running),
        .est_y_addr_b(est_y_addr), .est_y_dout_b(est_y_dout),
        .est_q_addr_b(est_q_addr), .est_q_dout_b(est_q_dout),
        .est_r_addr_b(est_r_addr), .est_r_dout_b(est_r_dout),
        
        // Output tr?ng thái c?a OMP Core
        .omp_done(core_done), .lambda_array_out(lambda_array_out)
    );

    // --- LÕI 2: GI?I H? PH??NG TRÌNH TÌM C??NG ?? (BACK-SUBSTITUTION) ---
    final_estimation_top #(.DW(DW)) u_final_est (
        .clk(clk), .rst_n(rst_n), .start_est(est_start),
        
        // N?i cáp ??c BRAM vào c?ng MUX do OMP_CORE cung c?p
        .y_addr(est_y_addr), .y_dout(est_y_dout),
        .q_addr(est_q_addr), .q_dout(est_q_dout),
        .r_addr(est_r_addr), .r_dout(est_r_dout), 
        
        // Xu?t k?t qu? cu?i cùng
        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid), .done_all(est_done)
    );

    // =========================================================================
    // 3. SYSTEM FSM (NH?C TR??NG T?I CAO ?I?U PH?I 2 LÕI)
    // =========================================================================
    localparam SYS_IDLE     = 2'd0,
               SYS_RUN_CORE = 2'd1, // Giai ?o?n 1: Ch?y OMP Core (Tìm K Lambda)
               SYS_RUN_EST  = 2'd2, // Giai ?o?n 2: Ch?y Final Est (Gi?i ph??ng trình)
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

    // Gán l?nh Logic T? h?p ?i?u khi?n các h? th?ng con d?a trên Tr?ng thái System
    assign core_start     = (sys_state == SYS_IDLE && start_system);
    assign est_start      = (sys_state == SYS_RUN_CORE && core_done);
    assign is_est_running = (sys_state == SYS_RUN_EST);
    assign system_done    = (sys_state == SYS_DONE);

endmodule