//`timescale 1ns / 1ps

//module tb_residual_update_full;

//    // --- Parameters ---
//    parameter DW = 24;          // Q10.13
//    parameter ADDR_W_Q = 8;     // 256 hàng
//    parameter DOT_W = 56;
//    parameter PERIOD = 10;      // 100MHz

//    // --- Signals ---
//    reg clk;
//    reg rst_n;
//    reg start_update;
//    reg [4:0] current_i;

//    // Interface k?t n?i RAM
//    wire [7:0]  q_addr_b;
//    reg  [95:0] q_dout_reg;
//    wire [3:0]  res_addr_a;
//    wire        res_we_a;
//    wire [95:0] res_din_a;
//    wire [3:0]  res_addr_b;
//    reg  [95:0] res_dout_reg;

//    wire update_done;

//    // --- Gi? l?p b? nh? BRAM n?i b? ---
//    reg [95:0] mem_q   [0:255]; // 16 vector Q, m?i vector 16 hàng
//    reg [95:0] mem_res [0:15];  // Vector th?ng d? r (16 hàng)

//    // --- DUT Instantiation (K?t n?i t??ng minh) ---
//    residual_update #(
//        .DW(DW), .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W)
//    ) dut (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start_update(start_update),
//        .current_i(current_i),
//        .M_rows(4'd15),
//        .q_addr_b(q_addr_b),
//        .q_dout_b(q_dout_reg),
//        .res_addr_a(res_addr_a),
//        .res_we_a(res_we_a),
//        .res_din_a(res_din_a),
//        .res_addr_b(res_addr_b),
//        .res_dout_b(res_dout_reg),
//        .update_done(update_done)
//    );

//    // --- Clock Generation ---
//    initial clk = 0;
//    always #(PERIOD/2) clk = ~clk;

//    // --- BRAM Latency-1 Simulation ---
//    // Mô ph?ng chính xác vi?c: ??a ch? nh?p T -> D? li?u ra nh?p T+1
//    always @(posedge clk) begin
//        q_dout_reg   <= mem_q[q_addr_b];
//        res_dout_reg <= mem_res[res_addr_b];
//        if (res_we_a) begin
//            mem_res[res_addr_a] <= res_din_a;
//        end
//    end

//    // --- Bi?n h? tr? ki?m tra sai s? ---
//    real r_real [0:63];
//    real q_real [0:63];
//    real alpha_expected;
//    real r_new_expected [0:63];
//    real hardware_val, hardware_alpha,expected_val;
//    real tolerance = 0.001;
//    integer i, k, error_count;

//    // --- Task: N?p d? li?u vào BRAM ---
//    task load_test_data(input integer q_idx);
//        begin
//            for (i=0; i<64; i=i+1) begin
//                // ?óng gói 4 ph?n t? vào 1 hàng 96-bit
//                if (i%4 == 0) begin
//                    mem_res[i/4][23:0]   = $rtoi(r_real[i] * 8192.0);
//                    mem_q[(q_idx<<4)+i/4][23:0] = $rtoi(q_real[i] * 8192.0);
//                end
//                if (i%4 == 1) begin
//                    mem_res[i/4][47:24]  = $rtoi(r_real[i] * 8192.0);
//                    mem_q[(q_idx<<4)+i/4][47:24]= $rtoi(q_real[i] * 8192.0);
//                end
//                if (i%4 == 2) begin
//                    mem_res[i/4][71:48]  = $rtoi(r_real[i] * 8192.0);
//                    mem_q[(q_idx<<4)+i/4][71:48]= $rtoi(q_real[i] * 8192.0);
//                end
//                if (i%4 == 3) begin
//                    mem_res[i/4][95:72]  = $rtoi(r_real[i] * 8192.0);
//                    mem_q[(q_idx<<4)+i/4][95:72]= $rtoi(q_real[i] * 8192.0);
//                end
//            end
//        end
//    endtask
//    initial begin
//        // --- KH?I T?O H? TH?NG ---
//        rst_n = 0; start_update = 0; current_i = 0; error_count = 0;
//        #100; rst_n = 1; #100;

//        $display("===========================================================");
//        $display("   KIEM TRA RESIDUAL UPDATE NANG CAO (Q10.13)");
//        $display("===========================================================");

//        // ---------------------------------------------------------
//        // TEST CASE 3: T??ng quan h?n h?p (S? d??ng & S? âm)
//        // r_old = [1.5, 0.5, 1.5, 0.5, ...]
//        // Q_i   = [0.1, 0.1, 0.1, 0.1, ...] (N?p vào c?t 3)
//        // Tính toán lý thuy?t:
//        // alpha = sum(r * Q) = 32*(1.5*0.1) + 32*(0.5*0.1) = 4.8 + 1.6 = 6.4
//        // r_new[hàng ch?n] = 1.5 - (6.4 * 0.1) = 0.86 (Hex Q13: 001B85)
//        // r_new[hàng l?]   = 0.5 - (6.4 * 0.1) = -0.14 (Hex Q13: FFFB85)
//        // ---------------------------------------------------------
//        for (i=0; i<64; i=i+1) begin 
//            r_real[i] = (i%2 == 0) ? 1.5 : 0.5; 
//            q_real[i] = 0.1; 
//        end
//        load_test_data(3); // N?p vào c?t 3 c?a RAM Q
        
//        $display("[%t] TEST 3: Tuong quan hon hop (alpha ky vong = 6.4)", $time);
//        current_i = 3;
//        @(posedge clk); start_update = 1;
//        @(posedge clk); start_update = 0;
//        wait(update_done); #50;
        
//        hardware_alpha = $itor($signed(dut.alpha_reg)) / 8192.0;
//        $display("   -> Alpha HW: %f", hardware_alpha);
        
//        // Ki?m tra 2 ph?n t? ??u (0.86 và -0.14)
//        for (k=0; k<2; k=k+1) begin
//            hardware_val = $itor($signed(mem_res[0][k*24 +: 24])) / 8192.0;
//            expected_val = (k%2 == 0) ? 0.86 : -0.14;
//            $display("   -> r_new[%0d] HW: %f (Expected: %f)", k, hardware_val, expected_val);
//            if (hardware_val > expected_val + tolerance || hardware_val < expected_val - tolerance)
//                error_count = error_count + 1;
//        end

//        #500;

//        // ---------------------------------------------------------
//        // TEST CASE 4: Stress Test v?i s? âm c?c ??i
//        // r_old = [-2.0, -2.0, ...]
//        // Q_i   = [0.1, 0.1, ...]
//        // alpha = 64 * (-2.0) * 0.1 = -12.8
//        // r_new = -2.0 - (-12.8 * 0.1) = -2.0 + 1.28 = -0.72
//        // ---------------------------------------------------------
//        for (i=0; i<64; i=i+1) begin 
//            r_real[i] = -2.0; 
//            q_real[i] = 0.1; 
//        end
//        load_test_data(7); // N?p vào c?t 7 c?a RAM Q
        
//        $display("\n[%t] TEST 4: So am va am (alpha ky vong = -12.8)", $time);
//        current_i = 7;
//        @(posedge clk); start_update = 1;
//        @(posedge clk); start_update = 0;
//        wait(update_done); #50;

//        hardware_alpha = $itor($signed(dut.alpha_reg)) / 8192.0;
//        hardware_val   = $itor($signed(mem_res[0][23:0])) / 8192.0;
//        $display("   -> Alpha HW: %f", hardware_alpha);
//        $display("   -> r_new[0] HW: %f (Expected: -0.72)", hardware_val);
        
//        if (hardware_val > -0.72 + tolerance || hardware_val < -0.72 - tolerance)
//            error_count = error_count + 1;

//        // --- T?NG K?T ---
//        $display("\n===========================================================");
//        if (error_count == 0) $display("   FINAL STATUS: EXCELLENT! HE THONG DAT DO CHINH XAC CAO.");
//        else                  $display("   FINAL STATUS: CO %0d LOI SAI SO.", error_count);
//        $display("===========================================================");
//        $finish;
//    end
//endmodule

`timescale 1ns / 1ps

module tb_residual_update_full();

    // --- Parameters ---
    parameter DW = 24;          // Q10.13
    parameter ADDR_W_Q = 8;     // 256 hàng t?ng
    parameter DOT_W = 56;
    parameter PERIOD = 10;      // 100MHz

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg start_update;
    reg [4:0] current_i;
    wire [3:0] M_rows = 4'd15; // C? ??nh 16 hàng cho test 16x16

    // Interface k?t n?i RAM
    wire [7:0]  q_addr_b;
    reg  [95:0] q_dout_reg;
    wire [3:0]  res_addr_a;
    wire        res_we_a;
    wire [95:0] res_din_a;
    wire [3:0]  res_addr_b;
    reg  [95:0] res_dout_reg;

    wire update_done;

    // --- Gi? l?p b? nh? BRAM n?i b? ---
    reg [95:0] mem_q   [0:255]; 
    reg [95:0] mem_res [0:15];  

    // --- DUT Instantiation ---
    residual_update #(
        .DW(DW), .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_update(start_update),
        .current_i(current_i),
        .M_rows(M_rows),
        .q_addr_b(q_addr_b),
        .q_dout_b(q_dout_reg),
        .res_addr_a(res_addr_a),
        .res_we_a(res_we_a),
        .res_din_a(res_din_a),
        .res_addr_b(res_addr_b),
        .res_dout_b(res_dout_reg),
        .update_done(update_done)
    );

    // --- Clock Generation ---
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

    // --- BRAM Latency-1 Simulation (QUAN TR?NG) ---
    always @(posedge clk) begin
        q_dout_reg   <= mem_q[q_addr_b];
        res_dout_reg <= mem_res[res_addr_b];
        if (res_we_a) begin
            mem_res[res_addr_a] <= res_din_a;
        end
    end

    // --- Bi?n h? tr? tính toán real-time ---
    real r_real [0:63];
    real q_real [0:63];
    real hardware_val, hardware_alpha, expected_val;
    real tolerance = 0.005; // Ng??ng sai s? do làm tròn Fixed-point
    integer i, k, error_count;

    // --- Task: N?p d? li?u vào BRAM ---
    task load_test_data(input integer q_idx);
        integer row, set;
        reg signed [23:0] q_fix, r_fix;
        begin
            for (row = 0; row < 16; row = row + 1) begin
                for (set = 0; set < 4; set = set + 1) begin
                    q_fix = $rtoi(q_real[row*4 + set] * 8192.0);
                    r_fix = $rtoi(r_real[row*4 + set] * 8192.0);
                    mem_q[(q_idx << 4) + row][set*24 +: 24] = q_fix;
                    mem_res[row][set*24 +: 24] = r_fix;
                end
            end
        end
    endtask

    initial begin
        // --- KH?I T?O ---
        rst_n = 0; start_update = 0; current_i = 0; error_count = 0;
        // Xóa s?ch RAM tránh giá tr? X
        for(i=0; i<256; i=i+1) mem_q[i] = 0;
        for(i=0; i<16; i=i+1) mem_res[i] = 0;
        
        #100; rst_n = 1; #100;

        $display("\n===========================================================");
        $display("   TEST 3: MIXED POLARITY (Alpha expected = 6.4)");
        $display("===========================================================");

        // r_old: xen k? 1.5 và 0.5. Q_i: toàn b? 0.1
        // Alpha = 32*(1.5*0.1) + 32*(0.5*0.1) = 4.8 + 1.6 = 6.4
        for (i=0; i<64; i=i+1) begin 
            r_real[i] = (i%2 == 0) ? 1.5 : 0.5; 
            q_real[i] = 0.1; 
        end
        load_test_data(3); 
        
        current_i = 3;
        @(posedge clk); start_update = 1;
        @(posedge clk); start_update = 0;
        
        wait(update_done); #100;
        
        hardware_alpha = $itor($signed(dut.alpha_reg)) / 8192.0;
        $display("[%t] -> Alpha HW: %f (Expected: 6.4)", $time, hardware_alpha);
        
        // Ki?m tra vài ?i?m r_new tiêu bi?u
        for (k=0; k<2; k=k+1) begin
            hardware_val = $itor($signed(mem_res[0][k*24 +: 24])) / 8192.0;
            expected_val = (k%2 == 0) ? (1.5 - 6.4*0.1) : (0.5 - 6.4*0.1);
            $display("   -> r_new[%0d] HW: %f (Expected: %f)", k, hardware_val, expected_val);
            if (abs_diff(hardware_val, expected_val) > tolerance) error_count = error_count + 1;
        end

        // ---------------------------------------------------------
        $display("\n===========================================================");
        $display("   TEST 4: STRESS NEGATIVE (Alpha expected = -12.8)");
        $display("===========================================================");
        // r_old: -2.0, Q_i: 0.1
        // Alpha = 64 * (-2.0 * 0.1) = -12.8
        for (i=0; i<64; i=i+1) begin 
            r_real[i] = -2.0; 
            q_real[i] = 0.1; 
        end
        load_test_data(7); 
        
        current_i = 7;
        @(posedge clk); start_update = 1;
        @(posedge clk); start_update = 0;
        
        wait(update_done); #100;

        hardware_alpha = $itor($signed(dut.alpha_reg)) / 8192.0;
        hardware_val   = $itor($signed(mem_res[0][23:0])) / 8192.0;
        $display("[%t] -> Alpha HW: %f (Expected: -12.8)", $time, hardware_alpha);
        $display("   -> r_new[0] HW: %f (Expected: -0.72)", hardware_val);
        
        if (abs_diff(hardware_val, -0.72) > tolerance) error_count = error_count + 1;

        // --- T?NG K?T ---
        $display("\n===========================================================");
        if (error_count == 0) 
            $display("   FINAL STATUS: PASSED! EXCELLENT ACCURACY.");
        else                  
            $display("   FINAL STATUS: FAILED! %0d ERRORS DETECTED.", error_count);
        $display("===========================================================\n");
        #100; $finish;
    end

    // Hàm tính sai s? tuy?t ??i
    function real abs_diff(input real a, input real b);
        abs_diff = (a > b) ? (a - b) : (b - a);
    endfunction

endmodule
