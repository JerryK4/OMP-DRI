`timescale 1ns / 1ps

module tb_omp_system_top_final();

    // --- Parameters ---
    parameter DW = 24;
    parameter PERIOD = 10; // 100MHz

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg start_system;

    wire [23:0] x_hat_val;
    wire [3:0]  x_hat_idx;
    wire        x_hat_valid;
    wire        done_all_system;

    wire [7:0]  monitor_lambda;
    wire [4:0]  monitor_iteration;

    // --- DUT Instantiation ---
    omp_system_top_final #(
        .DW(DW),
        .ADDR_W_PHI(12),
        .COL_W(8),
        .MAX_K(16)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_system(start_system),
        .x_hat_val(x_hat_val),
        .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid),
        .done_all_system(done_all_system),
        .monitor_lambda(monitor_lambda),
        .monitor_iteration(monitor_iteration)
    );

    // --- 1. Clock Generation ---
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

    // --- 2. File I/O (Ghi k?t qu? ra file .txt) ---
    integer file_ptr;
    initial begin
        file_ptr = $fopen("fpga_reconstructed_pixels.txt", "w");
        if (file_ptr == 0) begin
            $display("ERROR: Khong the tao file output!");
            $finish;
        end
        $fdisplay(file_ptr, "Index  Hex_Value  Real_Value");
    end

    // Ghi d? li?u khi x_hat_valid = 1
    always @(posedge clk) begin
        if (x_hat_valid) begin
            $fdisplay(file_ptr, "%d  %h  %f", 
                      x_hat_idx, 
                      x_hat_val, 
                      $itor($signed(x_hat_val)) / 8192.0);
            
            $display("[RESULT] Pixel %02d decoded: %f", x_hat_idx, $itor($signed(x_hat_val)) / 8192.0);
        end
    end

    // --- 3. Monitoring Lambda (Giám sát quá trình tìm ki?m) ---
    reg [4:0] prev_iteration;
    always @(posedge clk) begin
        if (rst_n && monitor_iteration != prev_iteration && monitor_iteration < 16) begin
            $display("    [OMP CORE] Iteration %0d: Found Lambda = %d (Hex: %h)", 
                     monitor_iteration, monitor_lambda, monitor_lambda);
            prev_iteration <= monitor_iteration;
        end
    end

    // --- 4. Main Stimulus (Lu?ng chính) ---
    real start_time, end_time;
    initial begin
        // Kh?i t?o ban ??u
        rst_n = 0;
        start_system = 0;
        prev_iteration = 5'h1F;

        $display("\n==========================================================");
        $display("   HE THONG SPC-OMP: BAT DAU MO PHONG");
        $display("==========================================================\n");

        #(PERIOD * 20);
        rst_n = 1;
        #(PERIOD * 20);

        // Kích ho?t h? th?ng
        start_time = $time;
        @(posedge clk);
        start_system = 1;
        @(posedge clk);
        start_system = 0;

        $display("[%0t] -> He thong dang chay...", $time);

        // ??i tín hi?u hoàn thành (S? d?ng wait ?úng context)
        wait(done_all_system == 1'b1);
        
        end_time = $time;

        $display("\n==========================================================");
        $display("   THUAT TOAN HOAN TAT!");
        $display("   Tong thoi gian thuc thi: %0.2f us", (end_time - start_time)/1000.0);
        $display("   Ket qua da luu vao file: fpga_reconstructed_pixels.txt");
        $display("==========================================================\n");

        $fclose(file_ptr);
        #(PERIOD * 50);
        $finish;
    end

endmodule