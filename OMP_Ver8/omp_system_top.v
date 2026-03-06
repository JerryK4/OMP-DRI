//////`timescale 1ns / 1ps

//////module omp_system_top #
//////(
//////    parameter DW         = 24,
//////    parameter ADDR_W_PHI = 12,
//////    parameter ROW_W      = 6,
//////    parameter COL_W      = 8,
//////    parameter ADDR_W_Q   = 8,
//////    parameter DOT_W      = 56,
//////    parameter MAX_I      = 16,
//////    parameter HIST_W     = 9
//////)
//////(
//////    input  wire                  clk,
//////    input  wire                  rst_n,
//////    input  wire                  start_system,
    
//////    // Tham s? c?u hình
//////    input  wire [COL_W-1:0]      N_cols,
//////    input  wire [ROW_W-1:0]      M_rows,
//////    input  wire [4:0]            K_sparsity,

//////    // Giao ti?p cho CPU n?p vector Y
//////    input  wire                  y_we_cpu,
//////    input  wire [3:0]            y_addr_cpu,
//////    input  wire [95:0]           y_din_cpu,

//////    // Output Data cho ph?n hi?n th? màn hình
//////    output wire [23:0]           x_hat_val,   // ?? sáng c?a pixel
//////    output wire [3:0]            x_hat_idx,   // Index th? t? (0 -> 15)
//////    output wire                  x_hat_valid, // Xung báo data h?p l?
    
//////    // Báo hi?u xong toàn b?
//////    output wire                  system_done,
//////    output wire [MAX_I*COL_W-1:0] lambda_array_out // Danh sách 16 t?a ?? (X,Y)
//////);

//////    // =========================================================================
//////    // 1. KHAI BÁO DÂY CHIA S? BRAM (BRAM INTERCONNECT)
//////    // =========================================================================
//////    wire [3:0]          est_y_addr_b;
//////    wire[95:0]         est_y_dout_b;

//////    wire [ADDR_W_Q-1:0] est_q_addr_b;
//////    wire [95:0]         est_q_dout_b;

//////    wire [7:0]          est_r_addr_b;
//////    wire[23:0]         est_r_dout_b;

//////    // C? báo hi?u cho phép Final Est giành quy?n MUX BRAM
//////    wire is_est_running;

//////    // =========================================================================
//////    // 2. INSTANTIATE 2 B? NÃO TOÁN H?C
//////    // =========================================================================
//////    wire core_start, core_done;
//////    wire est_start,  est_done;

//////    omp_core_engine #(
//////        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ROW_W(ROW_W), .COL_W(COL_W),
//////        .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W), .MAX_I(MAX_I), .HIST_W(HIST_W)
//////    ) u_omp_core (
//////        .clk(clk), .rst_n(rst_n), .start_omp(core_start),
//////        .N_cols(N_cols), .M_rows(M_rows), .K_sparsity(K_sparsity),
        
//////        // Giao ti?p CPU
//////        .y_we_cpu(y_we_cpu), .y_addr_cpu(y_addr_cpu), .y_din_cpu(y_din_cpu),
        
//////        // Giao ti?p MUX v?i Final Estimation
//////        .est_running_flag(is_est_running),
//////        .est_y_addr_b(est_y_addr_b), .est_y_dout_b(est_y_dout_b),
//////        .est_q_addr_b(est_q_addr_b), .est_q_dout_b(est_q_dout_b),
//////        .est_r_addr_b(est_r_addr_b), .est_r_dout_b(est_r_dout_b),
        
//////        // Output
//////        .omp_done(core_done), .lambda_array_out(lambda_array_out)
//////    );

//////    final_estimation_top #(.DW(DW)) u_final_est (
//////        .clk(clk), .rst_n(rst_n), .start_est(est_start),
        
//////        // N?i th?ng cáp vào OMP Core
//////        .y_addr(est_y_addr_b), .y_dout(est_y_dout_b),
//////        .q_addr(est_q_addr_b), .q_dout(est_q_dout_b),
//////        .r_addr(est_r_addr_b), .r_dout(est_r_dout_b), 
        
//////        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
//////        .x_hat_valid(x_hat_valid), .done_all(est_done)
//////    );

//////    // =========================================================================
//////    // 3. SYSTEM FSM (NH?C TR??NG T?I CAO)
//////    // =========================================================================
//////    localparam SYS_IDLE     = 2'd0,
//////               SYS_RUN_CORE = 2'd1, // Ch?y OMP Core (Tìm 16 Lambda, t?o Q, R)
//////               SYS_RUN_EST  = 2'd2, // Ch?y Final Est (Gi?i ph??ng trình Rx = Q'y)
//////               SYS_DONE     = 2'd3;

//////    reg [1:0] sys_state;

//////    always @(posedge clk or negedge rst_n) begin
//////        if (!rst_n) begin
//////            sys_state  <= SYS_IDLE;
//////        end else begin
//////            case (sys_state)
//////                SYS_IDLE: begin
//////                    if (start_system) sys_state <= SYS_RUN_CORE;
//////                end
                
//////                SYS_RUN_CORE: begin
//////                    if (core_done) sys_state <= SYS_RUN_EST;
//////                end

//////                SYS_RUN_EST: begin
//////                    if (est_done) sys_state <= SYS_DONE;
//////                end

//////                SYS_DONE: begin
//////                    sys_state <= SYS_IDLE;
//////                end
//////            endcase
//////        end
//////    end

//////    // Gán l?nh Logic T? h?p
//////    assign core_start     = (sys_state == SYS_IDLE && start_system);
//////    assign est_start      = (sys_state == SYS_RUN_CORE && core_done);
//////    assign is_est_running = (sys_state == SYS_RUN_EST);
//////    assign system_done    = (sys_state == SYS_DONE);

//////endmodule

////`timescale 1ns / 1ps

////module omp_system_top #
////(
////    parameter DW         = 24,
////    parameter ADDR_W_PHI = 12, // 4096 ??a ch?
////    parameter ROW_W      = 6,
////    parameter COL_W      = 8,
////    parameter ADDR_W_Q   = 8,
////    parameter DOT_W      = 56,
////    parameter MAX_I      = 16,
////    parameter HIST_W     = 9
////)
////(
////    input  wire                  clk,
////    input  wire                  rst_n,
////    input  wire                  start_system,
    
////    // Tham s? c?u hình OMP/DRI t? CPU
////    input  wire [COL_W-1:0]      N_cols,
////    input  wire [ROW_W-1:0]      M_rows,
////    input  wire [4:0]            K_sparsity,

////    // Giao ti?p cho DMA n?p vector Y
////    input  wire                  y_we_cpu,
////    input  wire [3:0]            y_addr_cpu,
////    input  wire [95:0]           y_din_cpu,

////    // Giao ti?p cho DMA n?p Ma tr?n PHI (?ã ??ng b?)
////    input  wire                  phi_we_cpu,
////    input  wire [ADDR_W_PHI-1:0] phi_addr_cpu,
////    input  wire [95:0]           phi_din_cpu,

////    // Output Data cho DMA/Màn hình (T? kh?i Final Estimation)
////    output wire [23:0]           x_hat_val,   // C??ng ?? sáng c?a pixel
////    output wire [3:0]            x_hat_idx,   // Index th? t? (0 -> K-1)
////    output wire                  x_hat_valid, // Xung báo data h?p l?
    
////    // Tín hi?u báo xong toàn b? h? th?ng
////    output wire                  system_done,
////    output wire [MAX_I*COL_W-1:0] lambda_array_out // Danh sách t?a ?? Lambda
////);

////    // =========================================================================
////    // 1. DÂY K?T N?I MUX ?? LÕI FINAL_ESTIMATION ??C BRAM T? OMP_CORE
////    // =========================================================================
////    wire [3:0]          est_y_addr;
////    wire[95:0]         est_y_dout;

////    wire [ADDR_W_Q-1:0] est_q_addr;
////    wire [95:0]         est_q_dout;

////    wire[7:0]          est_r_addr;
////    wire [23:0]         est_r_dout;

////    // C? báo hi?u cho phép Final Est giành quy?n MUX ??c BRAM
////    wire is_est_running;

////    // =========================================================================
////    // 2. INSTANTIATE 2 B? NÃO TÍNH TOÁN
////    // =========================================================================
////    wire core_start, core_done;
////    wire est_start,  est_done;

////    // --- LÕI 1: TÌM LAMBDA VÀ TR?C GIAO HÓA (CH?A S?N BRAM) ---
////    omp_core_engine #(
////        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ROW_W(ROW_W), .COL_W(COL_W),
////        .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W), .MAX_I(MAX_I), .HIST_W(HIST_W)
////    ) u_omp_core (
////        .clk(clk), .rst_n(rst_n), .start_omp(core_start),
////        .N_cols(N_cols), .M_rows(M_rows), .K_sparsity(K_sparsity),
        
////        // Giao ti?p CPU/DMA n?p Y
////        .y_we_cpu(y_we_cpu), .y_addr_cpu(y_addr_cpu), .y_din_cpu(y_din_cpu),
        
////        // Giao ti?p CPU/DMA n?p PHI
////        .phi_we_cpu(phi_we_cpu), .phi_addr_cpu(phi_addr_cpu), .phi_din_cpu(phi_din_cpu),
        
////        // Cung c?p c?ng ??c BRAM (MUX) cho kh?i Final Estimation
////        .est_running_flag(is_est_running),
////        .est_y_addr_b(est_y_addr), .est_y_dout_b(est_y_dout),
////        .est_q_addr_b(est_q_addr), .est_q_dout_b(est_q_dout),
////        .est_r_addr_b(est_r_addr), .est_r_dout_b(est_r_dout),
        
////        // Output tr?ng thái c?a OMP Core
////        .omp_done(core_done), .lambda_array_out(lambda_array_out)
////    );

////    // --- LÕI 2: GI?I H? PH??NG TRÌNH TÌM C??NG ?? (BACK-SUBSTITUTION) ---
////    final_estimation_top #(.DW(DW)) u_final_est (
////        .clk(clk), .rst_n(rst_n), .start_est(est_start),
        
////        // N?i cáp ??c BRAM vào c?ng MUX do OMP_CORE cung c?p
////        .y_addr(est_y_addr), .y_dout(est_y_dout),
////        .q_addr(est_q_addr), .q_dout(est_q_dout),
////        .r_addr(est_r_addr), .r_dout(est_r_dout), 
        
////        // Xu?t k?t qu? cu?i cùng
////        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
////        .x_hat_valid(x_hat_valid), .done_all(est_done)
////    );

////    // =========================================================================
////    // 3. SYSTEM FSM (NH?C TR??NG T?I CAO ?I?U PH?I 2 LÕI)
////    // =========================================================================
////    localparam SYS_IDLE     = 2'd0,
////               SYS_RUN_CORE = 2'd1, // Giai ?o?n 1: Ch?y OMP Core (Tìm K Lambda)
////               SYS_RUN_EST  = 2'd2, // Giai ?o?n 2: Ch?y Final Est (Gi?i ph??ng trình)
////               SYS_DONE     = 2'd3;

////    reg [1:0] sys_state;

////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            sys_state  <= SYS_IDLE;
////        end else begin
////            case (sys_state)
////                SYS_IDLE: begin
////                    if (start_system) sys_state <= SYS_RUN_CORE;
////                end
                
////                SYS_RUN_CORE: begin
////                    if (core_done) sys_state <= SYS_RUN_EST;
////                end

////                SYS_RUN_EST: begin
////                    if (est_done) sys_state <= SYS_DONE;
////                end

////                SYS_DONE: begin
////                    sys_state <= SYS_IDLE;
////                end
////            endcase
////        end
////    end

////    // Gán l?nh Logic T? h?p ?i?u khi?n các h? th?ng con d?a trên Tr?ng thái System
////    assign core_start     = (sys_state == SYS_IDLE && start_system);
////    assign est_start      = (sys_state == SYS_RUN_CORE && core_done);
////    assign is_est_running = (sys_state == SYS_RUN_EST);
////    assign system_done    = (sys_state == SYS_DONE);

////endmodule



//`timescale 1ns / 1ps

//module omp_system_top #
//(
//    // --- S?a: Tham s? h? th?ng ---
//    parameter NUM_MAC      = 4,     // S? b? MAC song song
//    parameter DW           = 24,    // ??nh d?ng 24-bit (Q11.13)
    
//    // --- S?a: Tham s? kích th??c ?nh (M?c ??nh cho 16x16) ---
//    parameter COL_W        = 8,     // N=256 -> 8 bit
//    parameter ROW_W        = 6,     // M_rows (M/4=16 -> 6 bit an toàn)
//    parameter K_W          = 5,     // K=16 -> 5 bit
//    parameter ROW_N        = 4,     // Stride: log2(16) = 4
    
//    // --- S?a: Tham s? ??a ch? RAM ---
//    parameter ADDR_W_PHI   = 12,    // Phi RAM: 4096 dòng
//    parameter ADDR_W_Q     = 12,    // Q RAM
//    parameter ADDR_W_R     = 12,    // R RAM
//    parameter ADDR_W_Y     = 6,     // Y RAM
    
//    // --- S?a: Tham s? tính toán ---
//    parameter DOT_W        = 56,
//    parameter MAX_I        = 16,    // Sparsity K t?i ?a
//    parameter VW           = 48,    // ?? r?ng vector v trung gian
    
//    // --- S?a: Tham s? Masking ---
//    parameter HIST_BIT_VLD = 1,
//    parameter HIST_W       = COL_W + HIST_BIT_VLD // S?a: T? ??ng tính 8+1=9
//)
//(
//    input  wire                  clk,
//    input  wire                  rst_n,
//    input  wire                  start_system,
    
//    // Tham s? c?u hình OMP/DRI t? CPU
//    input  wire [COL_W-1:0]      N_cols,
//    input  wire [ROW_W-1:0]      M_rows,
//    input  wire [K_W-1:0]        K_sparsity,

//    // Giao ti?p cho DMA n?p vector Y
//    input  wire                  y_we_cpu,
//    input  wire [ADDR_W_Y-1:0]   y_addr_cpu,   // S?a: Dùng ADDR_W_Y
//    input  wire [(NUM_MAC*DW)-1:0] y_din_cpu,  // S?a: Dùng NUM_MAC

//    // Giao ti?p cho DMA n?p Ma tr?n PHI
//    input  wire                  phi_we_cpu,
//    input  wire [ADDR_W_PHI-1:0] phi_addr_cpu,
//    input  wire [(NUM_MAC*DW)-1:0] phi_din_cpu, // S?a: Dùng NUM_MAC

//    // Output Data cho DMA/Màn hình (T? kh?i Final Estimation)
//    output wire [DW-1:0]         x_hat_val,   // S?a: Dùng DW
//    output wire [$clog2(MAX_I)-1:0] x_hat_idx, // S?a: T? ??ng tính ?? r?ng index
//    output wire                  x_hat_valid, 
    
//    // Tín hi?u báo xong toàn b? h? th?ng
//    output wire                  system_done,
//    output wire [MAX_I*COL_W-1:0] lambda_array_out 
//);

//    // =========================================================================
//    // 1. DÂY K?T N?I MUX (S?a: Tham s? hóa ?? r?ng bus d? li?u và ??a ch?)
//    // =========================================================================
//    wire [ADDR_W_Y-1:0]   est_y_addr;
//    wire [(NUM_MAC*DW)-1:0] est_y_dout;

//    wire [ADDR_W_Q-1:0]   est_q_addr;
//    wire [(NUM_MAC*DW)-1:0] est_q_dout;

//    wire [ADDR_W_R-1:0]   est_r_addr; // S?a: Dùng ADDR_W_R
//    wire [DW-1:0]         est_r_dout;

//    // C? báo hi?u cho phép Final Est giành quy?n MUX ??c BRAM
//    wire is_est_running;

//    // =========================================================================
//    // 2. INSTANTIATE 2 B? NÃO TÍNH TOÁN
//    // =========================================================================
//    wire core_start, core_done;
//    wire est_start,  est_done;

//    // --- LÕI 1: TÌM LAMBDA VÀ TR?C GIAO HÓA (S?a: Truy?n ??y ?? Parameter) ---
//    omp_core_engine #(
//        .NUM_MAC(NUM_MAC), .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ROW_W(ROW_W), 
//        .COL_W(COL_W), .ADDR_W_Q(ADDR_W_Q), .ADDR_W_R(ADDR_W_R), .ADDR_W_Y(ADDR_W_Y),
//        .ROW_N(ROW_N), .DOT_W(DOT_W), .MAX_I(MAX_I), .HIST_W(HIST_W)
//    ) u_omp_core (
//        .clk(clk), .rst_n(rst_n), .start_omp(core_start),
//        .N_cols(N_cols), .M_rows(M_rows), .K_sparsity(K_sparsity),
        
//        .y_we_cpu(y_we_cpu), .y_addr_cpu(y_addr_cpu), .y_din_cpu(y_din_cpu),
//        .phi_we_cpu(phi_we_cpu), .phi_addr_cpu(phi_addr_cpu), .phi_din_cpu(phi_din_cpu),
        
//        .est_running_flag(is_est_running),
//        .est_y_addr_b(est_y_addr), .est_y_dout_b(est_y_dout),
//        .est_q_addr_b(est_q_addr), .est_q_dout_b(est_q_dout),
//        .est_r_addr_b(est_r_addr), .est_r_dout_b(est_r_dout),
        
//        .omp_done(core_done), .lambda_array_out(lambda_array_out)
//    );

//    // --- LÕI 2: GI?I H? PH??NG TRÌNH TÌM C??NG ?? (S?a: Truy?n ??y ?? Parameter) ---
////    final_estimation_top #(
////        .NUM_MAC(NUM_MAC), .DW(DW), .DOT_W(DOT_W), .NUM_K(MAX_I),
////        .VW(VW), .ADDR_W_Y(ADDR_W_Y), .ADDR_W_Q(ADDR_W_Q), .ADDR_W_R(ADDR_W_R),
////        .ROW_N(ROW_N)
////    ) u_final_est (
////        .clk(clk), .rst_n(rst_n), .start_est(est_start),
        
////        .y_addr(est_y_addr), .y_dout(est_y_dout),
////        .q_addr(est_q_addr), .q_dout(est_q_dout),
////        .r_addr(est_r_addr), .r_dout(est_r_dout), 
        
////        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
////        .x_hat_valid(x_hat_valid), .done_all(est_done)
////    );
    
//    final_estimation_top #(.DW(DW)) u_final_est (
//        .clk(clk), .rst_n(rst_n), .start_est(est_start),
        
//        // N?i cáp ??c BRAM vào c?ng MUX do OMP_CORE cung c?p
//        .y_addr(est_y_addr), .y_dout(est_y_dout),
//        .q_addr(est_q_addr), .q_dout(est_q_dout),
//        .r_addr(est_r_addr), .r_dout(est_r_dout), 
        
//        // Xu?t k?t qu? cu?i cùng
//        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
//        .x_hat_valid(x_hat_valid), .done_all(est_done)
//    );
//    // =========================================================================
//    // 3. SYSTEM FSM (Tuy?t ??i gi? nguyên logic Nh?c tr??ng)
//    // =========================================================================
//    localparam SYS_IDLE     = 2'd0,
//               SYS_RUN_CORE = 2'd1, 
//               SYS_RUN_EST  = 2'd2, 
//               SYS_DONE     = 2'd3;

//    reg [1:0] sys_state;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            sys_state  <= SYS_IDLE;
//        end else begin
//            case (sys_state)
//                SYS_IDLE: begin
//                    if (start_system) sys_state <= SYS_RUN_CORE;
//                end
                
//                SYS_RUN_CORE: begin
//                    if (core_done) sys_state <= SYS_RUN_EST;
//                end

//                SYS_RUN_EST: begin
//                    if (est_done) sys_state <= SYS_DONE;
//                end

//                SYS_DONE: begin
//                    sys_state <= SYS_IDLE;
//                end
//            endcase
//        end
//    end

//    // Gán l?nh Logic T? h?p ?i?u khi?n các h? th?ng con d?a trên Tr?ng thái System
//    assign core_start     = (sys_state == SYS_IDLE && start_system);
//    assign est_start      = (sys_state == SYS_RUN_CORE && core_done);
//    assign is_est_running = (sys_state == SYS_RUN_EST);
//    assign system_done    = (sys_state == SYS_DONE);

//endmodule


`timescale 1ns / 1ps

module omp_system_top #
(
    parameter NUM_MAC    =4,
    parameter DW         = 24,
	parameter NUM_K      = 16,
    parameter ADDR_W_PHI = 12, // 4096 ??a ch?
	parameter ADDR_W_Y     = 4,
	parameter ADDR_W_R   = 8, 
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
    
    // Tham s? c?u h?nh OMP/DRI t? CPU
    input  wire [COL_W-1:0]      N_cols,
    input  wire [ROW_W-1:0]      M_rows,
    input  wire [$clog2(NUM_K):0]            K_sparsity,

    // Giao ti?p cho DMA n?p vector Y
    input  wire                  y_we_cpu,
    input  wire [ADDR_W_Y-1:0]            y_addr_cpu,
    input  wire [(NUM_MAC*DW)-1:0]           y_din_cpu,

    // Giao ti?p cho DMA n?p Ma tr?n PHI (?? ??ng b?)
    input  wire                  phi_we_cpu,
    input  wire [ADDR_W_PHI-1:0] phi_addr_cpu,
    input  wire [(NUM_MAC*DW)-1:0]           phi_din_cpu,

    // Output Data cho DMA/M?n h?nh (T? kh?i Final Estimation)
    output wire [DW-1:0]           x_hat_val,   // C??ng ?? s?ng c?a pixel
    output wire [$clog2(NUM_K)-1:0]            x_hat_idx,   // Index th? t? (0 -> K-1)
    output wire                  x_hat_valid, // Xung b?o data h?p l?
    
    // T?n hi?u b?o xong to?n b? h? th?ng
    output wire                  system_done,
    output wire [MAX_I*COL_W-1:0] lambda_array_out // Danh s?ch t?a ?? Lambda
);

    // =========================================================================
    // 1. D?Y K?T N?I MUX ?? L?I FINAL_ESTIMATION ??C BRAM T? OMP_CORE
    // =========================================================================
    wire [ADDR_W_Y-1:0]          est_y_addr;
    wire[(NUM_MAC*DW)-1:0]         est_y_dout;

    wire [ADDR_W_Q-1:0] est_q_addr;
    wire [(NUM_MAC*DW)-1:0]         est_q_dout;

    wire[ADDR_W_R-1:0]          est_r_addr;
    wire [DW-1:0]         est_r_dout;

    // C? b?o hi?u cho ph?p Final Est gi?nh quy?n MUX ??c BRAM
    wire is_est_running;

    // =========================================================================
    // 2. INSTANTIATE 2 B? N?O T?NH TO?N
    // =========================================================================
    wire core_start, core_done;
    wire est_start,  est_done;

    // --- L?I 1: T?M LAMBDA V? TR?C GIAO H?A (CH?A S?N BRAM) ---
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
        
        // Output tr?ng th?i c?a OMP Core
        .omp_done(core_done), .lambda_array_out(lambda_array_out)
    );

    // --- L?I 2: GI?I H? PH??NG TR?NH T?M C??NG ?? (BACK-SUBSTITUTION) ---
    final_estimation_top #(.DW(DW)) u_final_est (
        .clk(clk), .rst_n(rst_n), .start_est(est_start),
        
        // N?i c?p ??c BRAM v?o c?ng MUX do OMP_CORE cung c?p
        .y_addr(est_y_addr), .y_dout(est_y_dout),
        .q_addr(est_q_addr), .q_dout(est_q_dout),
        .r_addr(est_r_addr), .r_dout(est_r_dout), 
        
        // Xu?t k?t qu? cu?i c?ng
        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid), .done_all(est_done)
    );

    // =========================================================================
    // 3. SYSTEM FSM (NH?C TR??NG T?I CAO ?I?U PH?I 2 L?I)
    // =========================================================================
    localparam SYS_IDLE     = 2'd0,
               SYS_RUN_CORE = 2'd1, // Giai ?o?n 1: Ch?y OMP Core (T?m K Lambda)
               SYS_RUN_EST  = 2'd2, // Giai ?o?n 2: Ch?y Final Est (Gi?i ph??ng tr?nh)
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

    // G?n l?nh Logic T? h?p ?i?u khi?n c?c h? th?ng con d?a tr?n Tr?ng th?i System
    assign core_start     = (sys_state == SYS_IDLE && start_system);
    assign est_start      = (sys_state == SYS_RUN_CORE && core_done);
    assign is_est_running = (sys_state == SYS_RUN_EST);
    assign system_done    = (sys_state == SYS_DONE);

endmodule