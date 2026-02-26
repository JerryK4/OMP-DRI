`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 08:27:05 AM
// Design Name: 
// Module Name: tb_omp_system_top
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


module tb_omp_system_top;

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
    
    reg  [COL_W-1:0] N_cols;
    reg[ROW_W-1:0] M_rows;
    reg  [4:0]       K_sparsity;

    // CPU Port (?? không)
    reg          y_we_cpu;
    reg  [3:0]   y_addr_cpu;
    reg  [95:0]  y_din_cpu;

    // Tín hi?u Output t? System Top
    wire [23:0]  x_hat_val;
    wire [3:0]   x_hat_idx;
    wire         x_hat_valid;
    
    wire         system_done;
    wire[MAX_I*COL_W-1:0] lambda_array_out;

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

    // "M?" m?ng 1D thành 2D ?? ánh x? v?i x_hat_idx
    wire [7:0] lambda_result[0:MAX_I-1];
    genvar g;
    generate
        for (g = 0; g < MAX_I; g = g + 1) begin : gen_unpack
            assign lambda_result[g] = lambda_array_out[g*COL_W +: COL_W];
        end
    endgenerate

    // =========================================================================
    // 3. THEO DÕI FSM C?A SYSTEM VÀ IN LOG CONSOLE
    // =========================================================================
    reg [1:0] prev_sys_state;
    always @(posedge clk) begin
        if (rst_n && dut.sys_state != prev_sys_state) begin
            case(dut.sys_state)
                2'd1: $display("\n[%0t ns] >>> H? TH?NG: KÍCH HO?T OMP CORE (Tìm Lambda & Tr?c giao)...", $time/1000);
                2'd2: $display("\n[%0t ns] >>> H? TH?NG: KÍCH HO?T FINAL ESTIMATION (Gi?i ph??ng trình Rx=v)...", $time/1000);
                2'd3: $display("\n[%0t ns] >>> H? TH?NG: HOÀN T?T TOÀN B? QUÁ TRÌNH!", $time/1000);
            endcase
            prev_sys_state <= dut.sys_state;
        end
    end

    // =========================================================================
    // 4. B? GHI FILE TEXT (FILE I/O LOGGER)
    // =========================================================================
    integer file_id;
    real val_float;

    initial begin
        // M? file text ?? Ghi ("w" = write mode)
        file_id = $fopen("omp_reconstruction_results.txt", "w");
        if (file_id == 0) begin
            $display("L?I: Không th? t?o file txt!");
            $finish;
        end
        $fdisplay(file_id, "=========================================================");
        $fdisplay(file_id, "       K?T QU? KHÔI PH?C CAMERA ??N ?I?M (OMP-DRI)");
        $fdisplay(file_id, "=========================================================\n");
        $fdisplay(file_id, "Vòng l?p | T?a ?? Pixel (Lambda) | C??ng ?? (Hex) | C??ng ?? (Float Q10.13)");
        $fdisplay(file_id, "-------------------------------------------------------------------------");
    end

    // Ch?p d? li?u ngay khi c? x_hat_valid b?t lên
    always @(posedge clk) begin
        if (rst_n && x_hat_valid) begin
            // Gi? s? x_hat_val mang ??nh d?ng Q10.13, chia cho 2^13 (8192.0) ?? ra s? th?c
            val_float = $signed(x_hat_val) / 8192.0; 
            
            // 1. Ghi vào File Text
            $fdisplay(file_id, "   %2d    |         %3d           |     %6x   |      %f", 
                      x_hat_idx, lambda_result[x_hat_idx], x_hat_val, val_float);
            
            // 2. In ra Console ?? xem tr?c ti?p
            $display("[%0t ns] [GHI FILE] Pixel Lambda = %0d \t-> C??ng ?? sáng = %f", 
                     $time/1000, lambda_result[x_hat_idx], val_float);
        end
    end

    // =========================================================================
    // 5. K?CH B?N MÔ PH?NG CHÍNH
    // =========================================================================
    initial begin
        // Kh?i t?o h? th?ng
        rst_n = 0; start_system = 0; prev_sys_state = 0;
        
        y_we_cpu   = 0; 
        y_addr_cpu = 0; 
        y_din_cpu  = 0;

        // C?u hình (?nh 16x16 -> N=256, M=64 phép ?o, K=16 pixel sáng)
        N_cols     = 8'd255; 
        M_rows     = 6'd15;  
        K_sparsity = 5'd16;  

        // Ch? BRAM kh?i t?o d? li?u t? file .coe
        #(CLK_PERIOD * 15);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("=========================================================");
        $display("   START SIMULATION: SYSTEM LEVEL (CORE + ESTIMATION)");
        $display("=========================================================");
        
        // Kích ho?t toàn b? h? th?ng
        start_system = 1;
        #(CLK_PERIOD);
        start_system = 0;

        // Ch? H? th?ng báo xong
        wait(system_done == 1'b1);
        #(CLK_PERIOD * 10);

        // ?óng file Text l?i
        $fclose(file_id);
        
        $display("\n=========================================================");
        $display("   THÀNH CÔNG! B?N HÃY M? FILE .TXT LÊN ?? XEM K?T QU?");
        $display("=========================================================\n");
        $finish;
    end

endmodule
