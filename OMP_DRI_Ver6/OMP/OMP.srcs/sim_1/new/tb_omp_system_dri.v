`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 08:26:18 AM
// Design Name: 
// Module Name: tb_omp_system_dri
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_omp_system_dri;

    // --- Tham s? h? th?ng ---
    parameter CLK_PERIOD = 10; // 100MHz
    parameter DW         = 24;
    parameter COL_W      = 8;
    parameter ROW_W      = 6;
    parameter MAX_I      = 16;

    // --- Tín hi?u giao ti?p ---
    reg  clk;
    reg  rst_n;
    reg  start_system;
    
    // CÁC BI?N ?I?U KHI?N DRI (S? ???c thay ??i linh ho?t lúc Runtime)
    reg  [COL_W-1:0] N_cols;
    reg  [ROW_W-1:0] M_rows;
    reg[4:0]       K_sparsity;

    // CPU Port (?? không)
    reg          y_we_cpu;
    reg  [3:0]   y_addr_cpu;
    reg  [95:0]  y_din_cpu;

    // Tín hi?u Output t? System Top
    wire [23:0]  x_hat_val;
    wire [3:0]   x_hat_idx;
    wire         x_hat_valid;
    
    wire         system_done;
    wire [MAX_I*COL_W-1:0] lambda_array_out;

    // =========================================================================
    // 1. INSTANTIATE SYSTEM TOP (DUT)
    // =========================================================================
    omp_system_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_system(start_system),
        .N_cols(N_cols),
        .M_rows(M_rows),
        .K_sparsity(K_sparsity),
        
        .y_we_cpu(y_we_cpu),
        .y_addr_cpu(y_addr_cpu),
        .y_din_cpu(y_din_cpu),
        
        .x_hat_val(x_hat_val),
        .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid),
        
        .system_done(system_done),
        .lambda_array_out(lambda_array_out)
    );

    // =========================================================================
    // 2. T?O CLOCK & GI?I MÃ LAMBDA ARRAY
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    wire[7:0] lambda_result[0:MAX_I-1];
    genvar g;
    generate
        for (g = 0; g < MAX_I; g = g + 1) begin : gen_unpack
            assign lambda_result[g] = lambda_array_out[g*COL_W +: COL_W];
        end
    endgenerate

    // =========================================================================
    // 3. THEO DÕI FSM VÀ B? GHI FILE (DRI LOGGER)
    // =========================================================================
    integer file_id;
    real val_float;
    
    // Bi?n String ?? ?ánh d?u ?? phân gi?i hi?n t?i khi in file
    reg [8*8-1:0] current_res_str; 

    initial begin
        // M? file txt
        file_id = $fopen("omp_dri_progressive_results.txt", "w");
        if (file_id == 0) begin
            $display("L?I: Không th? t?o file txt!");
            $finish;
        end
        $fdisplay(file_id, "=======================================================================");
        $fdisplay(file_id, "    K?T QU? KHÔI PH?C ?? PHÂN GI?I ??NG (DRI) - SINGLE PIXEL CAMERA");
        $fdisplay(file_id, "=======================================================================\n");
    end

    // Ghi d? li?u vào file
    always @(posedge clk) begin
        if (rst_n && x_hat_valid) begin
            val_float = $signed(x_hat_val) / 8192.0; // Q10.13 to Float
            
            $fdisplay(file_id, "[%s] Vòng %2d | Pixel Lambda = %3d | C??ng ?? = %f", 
                      current_res_str, x_hat_idx, lambda_result[x_hat_idx], val_float);
            
            $display("[%0t ns] [%s] Xu?t Pixel Lambda %0d -> %f", 
                     $time/1000, current_res_str, lambda_result[x_hat_idx], val_float);
        end
    end

    // In theo dõi h? th?ng
    reg [1:0] prev_sys_state;
    always @(posedge clk) begin
        if (rst_n && dut.sys_state != prev_sys_state) begin
            if (dut.sys_state == 2'd3) 
                $display("\n[%0t ns] >>> HOÀN T?T ?? PHÂN GI?I %s <<<\n", $time/1000, current_res_str);
            prev_sys_state <= dut.sys_state;
        end
    end

    // =========================================================================
    // 4. K?CH B?N CH?Y DRI LIÊN HOÀN (4x4 -> 8x8 -> 16x16)
    // =========================================================================
    initial begin
        // Kh?i t?o h? th?ng
        rst_n = 0; start_system = 0; prev_sys_state = 0;
        y_we_cpu = 0; y_addr_cpu = 0; y_din_cpu = 0;

        // Ch? BRAM kh?i t?o
        #(CLK_PERIOD * 15);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------------
        // GIAI ?O?N 1: KHÔI PH?C ?NH NHÁP (PREVIEW 4x4)
        // D?a theo b?ng thông s? Table I trong bài báo IEEE
        // N = 16 (0->15), M = 8 phép ?o (2 hàng RAM), K = 4
        // ---------------------------------------------------------------------
        $display("=========================================================");
        $display("[GIAI ?O?N 1] CH?Y ?? PHÂN GI?I 4x4 (M=8, K=4)");
        $display("=========================================================");
        $fdisplay(file_id, "--- ?? PHÂN GI?I 4x4 (N=16, M=8, K=4) ---");
        
        current_res_str = "  4x4  ";
        N_cols     = 8'd15; // 16 pixel - 1
        M_rows     = 6'd1;  // 8 phép ?o / 4 = 2 hàng -> Index cao nh?t là 1
        K_sparsity = 5'd4;  // Quét 4 ?i?m sáng
        
        start_system = 1; #(CLK_PERIOD); start_system = 0;
        wait(system_done == 1'b1); #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------------
        // GIAI ?O?N 2: T?NG ?? NÉT LÊN (8x8) T?N D?NG D? LI?U C?
        // N = 64 (0->63), M = 16 phép ?o (4 hàng RAM), K = 6
        // ---------------------------------------------------------------------
        $display("=========================================================");
        $display("   [GIAI ?O?N 2] NÂNG ?? PHÂN GI?I 8x8 (M=16, K=6)");
        $display("=========================================================");
        $fdisplay(file_id, "\n--- ?? PHÂN GI?I 8x8 (N=64, M=16, K=6) ---");

        current_res_str = "  8x8  ";
        N_cols     = 8'd63; // 64 pixel - 1
        M_rows     = 6'd3;  // 16 phép ?o / 4 = 4 hàng -> Index cao nh?t là 3
        K_sparsity = 5'd6;  // Quét 6 ?i?m sáng
        
        start_system = 1; #(CLK_PERIOD); start_system = 0;
        wait(system_done == 1'b1); #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------------
        // GIAI ?O?N 3: HOÀN THI?N ?NH ?? NÉT CAO (16x16)
        // N = 256 (0->255), M = 64 phép ?o (16 hàng RAM), K = 16
        // ---------------------------------------------------------------------
        $display("=========================================================");
        $display("   [GIAI ?O?N 3] HOÀN THI?N ?? PHÂN GI?I 16x16 (M=64, K=16)");
        $display("=========================================================");
        $fdisplay(file_id, "\n--- ?? PHÂN GI?I 16x16 (N=256, M=64, K=16) ---");

        current_res_str = " 16x16 ";
        N_cols     = 8'd255; // 256 pixel - 1
        M_rows     = 6'd15;  // 64 phép ?o / 4 = 16 hàng -> Index cao nh?t là 15
        K_sparsity = 5'd16;  // Quét 16 ?i?m sáng
        
        start_system = 1; #(CLK_PERIOD); start_system = 0;
        wait(system_done == 1'b1); #(CLK_PERIOD * 10);

        // ---------------------------------------------------------------------
        // K?T THÚC
        // ---------------------------------------------------------------------
        $fclose(file_id);
        $display("\n=========================================================");
        $display(" THÀNH CÔNG! ?Ã GHI TOÀN B? QUÁ TRÌNH DRI VÀO FILE TXT.");
        $display("=========================================================\n");
        $finish;
    end

endmodule
