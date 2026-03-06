`timescale 1ns / 1ps

module tb_omp_system_dri;

    // =========================================================================
    // 1. THAM S? H? TH?NG (??nh ngh?a t?p trung t?i ?ây)
    // =========================================================================
    parameter CLK_PERIOD   = 10;    // 100MHz
    parameter NUM_MAC      = 4;     // S? b? nhân MAC song song
    parameter DW           = 24;    // ?? r?ng d? li?u Q11.13
    
    // Kích th??c t?i ?a (cho c?u hình 16x16)
    parameter COL_W        = 8;     // N=256 -> 8 bit
    parameter ROW_W        = 6;     // M/4=16 -> 6 bit
    parameter K_W          = 5;     // K=16 -> 5 bit
    parameter MAX_I        = 16;    // S? nguyên t? t?i ?a
    
    // Thông s? b? nh? và tính toán
    parameter ADDR_W_PHI   = 12;
    parameter ADDR_W_Q     = 12;
    parameter ADDR_W_R     = 12;
    parameter ADDR_W_Y     = 6;
    parameter ROW_N_16x16  = 4;     // Stride ??a ch? cho 16x16 (log2(64/4)=4)
    parameter DOT_W        = 56;
    parameter VW           = 48;    // ?? r?ng vector v trung gian

    // =========================================================================
    // 2. TÍN HI?U GIAO TI?P
    // =========================================================================
    reg  clk;
    reg  rst_n;
    reg  start_system;
    
    // C?u hình DRI (Thay ??i ??ng trong initial block)
    reg [COL_W-1:0] N_cols;
    reg [ROW_W-1:0] M_rows;
    reg [K_W-1:0]   K_sparsity;

    // CPU/DMA Interface (?? r?ng tính toán theo NUM_MAC)
    reg                     y_we_cpu;
    reg [ADDR_W_Y-1:0]      y_addr_cpu;
    reg [(NUM_MAC*DW)-1:0]  y_din_cpu;
    reg                     phi_we_cpu;
    reg [ADDR_W_PHI-1:0]    phi_addr_cpu;
    reg [(NUM_MAC*DW)-1:0]  phi_din_cpu;

    // Output t? DUT
    wire [DW-1:0]           x_hat_val;
    wire [$clog2(MAX_I)-1:0] x_hat_idx;
    wire                    x_hat_valid;
    wire                    system_done;
    wire [MAX_I*COL_W-1:0]  lambda_array_out;

    // =========================================================================
    // 3. KH?I T?O DUT (TRUY?N ??Y ?? PARAMETER)
    // =========================================================================
    omp_system_top #(
        .NUM_MAC(NUM_MAC),
        .DW(DW),
        .COL_W(COL_W),
        .ROW_W(ROW_W),
        .K_W(K_W),
        .ROW_N(ROW_N_16x16),
        .ADDR_W_PHI(ADDR_W_PHI),
        .ADDR_W_Q(ADDR_W_Q),
        .ADDR_W_R(ADDR_W_R),
        .ADDR_W_Y(ADDR_W_Y),
        .DOT_W(DOT_W),
        .MAX_I(MAX_I),
        .VW(VW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_system(start_system),
        .N_cols(N_cols),
        .M_rows(M_rows),
        .K_sparsity(K_sparsity),
        .y_we_cpu(y_we_cpu),
        .y_addr_cpu(y_addr_cpu),
        .y_din_cpu(y_din_cpu),
        .phi_we_cpu(phi_we_cpu),
        .phi_addr_cpu(phi_addr_cpu),
        .phi_din_cpu(phi_din_cpu),
        .x_hat_val(x_hat_val),
        .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid),
        .system_done(system_done),
        .lambda_array_out(lambda_array_out)
    );

    // =========================================================================
    // 4. TI?N ÍCH MÔ PH?NG (Clock, Unpack, Logging)
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Gi?i mã m?ng Lambda ?? xem trên Waveform
    wire [COL_W-1:0] lambda_result [0:MAX_I-1];
    genvar g;
    generate
        for (g = 0; g < MAX_I; g = g + 1) begin : gen_unpack
            assign lambda_result[g] = lambda_array_out[g*COL_W +: COL_W];
        end
    endgenerate

    // Logger File
    integer file_id;
    reg [8*8-1:0] current_res_str; 

    initial begin
        file_id = $fopen("omp_dri_progressive_results.txt", "w");
        $fdisplay(file_id, "=========================================================");
        $fdisplay(file_id, "    K?T QU? KHÔI PH?C DRI - SINGLE PIXEL CAMERA");
        $fdisplay(file_id, "=========================================================\n");
    end

    // Ghi file khi có k?t qu? pixel valid
    always @(posedge clk) begin
        if (rst_n && x_hat_valid) begin
            $fdisplay(file_id, "[%s] Index %2d | Lambda %3d | Val %f", 
                      current_res_str, x_hat_idx, lambda_result[x_hat_idx], $signed(x_hat_val)/8192.0);
            
            $display("[%0t ns] [%s] Result: Pixel %0d (Lambda %0d) = %f", 
                     $time, current_res_str, x_hat_idx, lambda_result[x_hat_idx], $signed(x_hat_val)/8192.0);
        end
    end

    // Theo dõi tr?ng thái FSM qua Console
    reg [1:0] prev_sys_state;
    always @(posedge clk) begin
        if (rst_n && dut.sys_state != prev_sys_state) begin
            if (dut.sys_state == 2'd1) $display("\n[%0t ns] >>> B?T ??U OMP CORE (%s) <<<", $time, current_res_str);
            if (dut.sys_state == 2'd2) $display("[%0t ns] >>> B?T ??U GI?I Rx=v <<<", $time);
            if (dut.sys_state == 2'd3) $display("[%0t ns] >>> HOÀN T?T ?? PHÂN GI?I %s <<<\n", $time, current_res_str);
            prev_sys_state <= dut.sys_state;
        end
    end

    // =========================================================================
    // 5. K?CH B?N CH?Y DRI (4x4 -> 8x8 -> 16x16)
    // =========================================================================
    initial begin
        // Reset h? th?ng
        rst_n = 0; start_system = 0; prev_sys_state = 0;
        y_we_cpu = 0; y_addr_cpu = 0; y_din_cpu = 0;
        phi_we_cpu = 0; phi_addr_cpu = 0; phi_din_cpu = 0;

        // Ch? n?p BRAM t? file .coe
        #(CLK_PERIOD * 25);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        // --- GIAI ?O?N 1: 4x4 (N=16, M=8, K=4) ---
        $display("---------------------------------------------------------");
        $display("[STAGE 1] Running 4x4 Preview...");
        current_res_str = "  4x4  ";
        N_cols     = 8'd15;   // N-1 = 15
        M_rows     = 6'd1;    // (M/4)-1 = (8/4)-1 = 1
        K_sparsity = 5'd4;    
        start_system = 1; #(CLK_PERIOD); start_system = 0;
        wait(system_done); #(CLK_PERIOD * 50);

        // --- GIAI ?O?N 2: 8x8 (N=64, M=16, K=6) ---
        $display("---------------------------------------------------------");
        $display("[STAGE 2] Upgrading to 8x8...");
        current_res_str = "  8x8  ";
        N_cols     = 8'd63;   // N-1 = 63
        M_rows     = 6'd3;    // (M/4)-1 = (16/4)-1 = 3
        K_sparsity = 5'd6;    
        start_system = 1; #(CLK_PERIOD); start_system = 0;
        wait(system_done); #(CLK_PERIOD * 50);

        // --- GIAI ?O?N 3: 16x16 (N=256, M=64, K=16) ---
        $display("---------------------------------------------------------");
        $display("[STAGE 3] Final 16x16 Reconstruction...");
        current_res_str = " 16x16 ";
        N_cols     = 8'd255;  // N-1 = 255
        M_rows     = 6'd15;   // (M/4)-1 = (64/4)-1 = 15
        K_sparsity = 5'd16;   
        start_system = 1; #(CLK_PERIOD); start_system = 0;
        wait(system_done); #(CLK_PERIOD * 100);

        // K?t thúc
        $fclose(file_id);
        $display("\n=========================================================");
        $display("   DRI SIMULATION SUCCESSFUL! CHECK LOG FILE.");
        $display("=========================================================\n");
        $finish;
    end

endmodule