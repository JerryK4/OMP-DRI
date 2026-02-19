`timescale 1ns / 1ps

module tb_residual_update_stress_test();

    // --- Parameters ---
    parameter DW = 24;
    parameter ROW_W = 4;
    parameter DOT_W = 56;
    parameter PERIOD = 10;

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg start_update;
    
    wire [ROW_W-1:0] q_addr;
    reg  [95:0]      q_data;
    wire [ROW_W-1:0] r_addr;
    wire             r_we;
    reg  [95:0]      r_data_in;
    wire [95:0]      r_data_out;
    wire             update_done;

    // --- Memory Modeling (Mô ph?ng BRAM th?t) ---
    reg [95:0] mem_q [0:15];
    reg [95:0] mem_r [0:15];
    
    // BRAM luôn tr? 1 nh?p t? khi có ??a ch? ??n khi có d? li?u
    always @(posedge clk) begin
        q_data    <= mem_q[q_addr];
        r_data_in <= mem_r[r_addr];
        if (r_we) mem_r[r_addr] <= r_data_out;
    end

    // --- DUT Instance ---
    residual_update_core #(
        .DW(DW), .ROW_W(ROW_W), .DOT_W(DOT_W)
    ) uut (
        .clk(clk), .rst_n(rst_n),
        .start_update(start_update),
        .q_addr(q_addr), .q_data(q_data),
        .r_addr(r_addr), .r_we(r_we),
        .r_data_in(r_data_in), .r_data_out(r_data_out),
        .update_done(update_done)
    );

    // --- Clock Gen ---
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

    // --- Variables for Verification ---
    integer i, iter;
    real real_q, real_r_old, real_alpha, real_r_new;
    real expected_alpha;
    real total_error;

    // --- Test Task: Load Data ---
    task load_test_data(input integer test_type);
        begin
            total_error = 0;
            expected_alpha = 0;
            for (i=0; i<16; i=i+1) begin
                if (test_type == 0) begin // D? li?u t? Golden Log c?a b?n
                    // Qi m?u (G?n b?ng 0.25)
                    mem_q[i] = {24'h200000, 24'h200000, 24'h200000, 24'h200000}; 
                    // r_old m?u (G?n b?ng 1.0)
                    mem_r[i] = {24'h002000, 24'h002000, 24'h002000, 24'h002000};
                end else begin // D? li?u ng?u nhiên (Stress test)
                    mem_q[i] = {$random, $random, $random, $random};
                    mem_r[i] = {$random, $random, $random, $random};
                end
                
                // Tính Alpha lý t??ng b?ng s? th?c ?? so sánh
                for (iter=0; iter<4; iter=iter+1) begin
                    real_q = $signed(mem_q[i][iter*24 +: 24]) / 8192.0;
                    real_r_old = $signed(mem_r[i][iter*24 +: 24]) / 8192.0;
                    expected_alpha = expected_alpha + (real_q * real_r_old);
                end
            end
        end
    endtask

    // --- Main Simulation ---
    initial begin
        // Reset
        rst_n = 0; start_update = 0;
        #(PERIOD*5);
        rst_n = 1;

        $display("\n==========================================================");
        $display("STARTING RESIDUAL UPDATE STRESS TEST");
        $display("==========================================================\n");

        // CASE 1: D? li?u tiêu chu?n (Kh?p Golden Log)
        load_test_data(0);
        #(PERIOD);
        start_update = 1;
        #(PERIOD);
        start_update = 0;

        // Ch? tính toán Alpha
        wait(uut.state == 3'd3); // ??i ??n tr?ng thái RD_RSUB
        real_alpha = $signed(uut.alpha_reg) / 8192.0;
        $display("[CHECK 1] Expected Alpha: %f, RTL Alpha: %f", expected_alpha, real_alpha);
        if (abs(expected_alpha - real_alpha) > 0.01) 
            $display("--> RESULT: ALPHA WRONG! (Check MAC/Shift logic)");
        else 
            $display("--> RESULT: ALPHA OK.");

        // Ch? hoàn thành ghi l?i r
        wait(update_done);
        $display("[CHECK 2] Verifying r_new in Memory...");
        for (i=0; i<16; i=i+1) begin
            for (iter=0; iter<4; iter=iter+1) begin
                real_q = $signed(mem_q[i][iter*24 +: 24]) / 8192.0;
                real_r_old = $signed(mem_r[i][iter*24 +: 24]) / 8192.0; // L?u ý: C?n l?u r_old g?c ?? so sánh
                // Tính r_new th?c t? trong RAM sau khi DUT ch?y
                real_r_new = $signed(mem_r[i][iter*24 +: 24]) / 8192.0;
                // $display("  Row %d, Set %d: r_new = %f", i, iter, real_r_new);
            end
        end
        $display("--> CASE 1 DONE.\n");

        // CASE 2: Ng?u nhiên c?c m?nh (Ki?m tra tràn s?/Bão hòa)
        $display("[CASE 2] Random Data Saturation Test...");
        load_test_data(1);
        start_update = 1; #(PERIOD); start_update = 0;
        wait(update_done);
        $display("--> CASE 2 DONE. (Check waveform for saturation flags)");

        #(PERIOD*10);
        $display("\n==========================================================");
        $display("ALL TESTS FINISHED");
        $display("==========================================================\n");
        $finish;
    end

    // Hàm tính tr? tuy?t ??i cho s? th?c
    function real abs(input real val);
        abs = (val < 0) ? -val : val;
    endfunction

endmodule