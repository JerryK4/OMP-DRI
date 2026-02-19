//`timescale 1ns / 1ps

//module tb_omp_core_top();

//    // --- 1. Tham s? h? th?ng ---
//    parameter DW = 24;
//    parameter PERIOD = 10; // 100 MHz
//    parameter MAX_K = 16;

//    reg clk;
//    reg rst_n;
//    reg start_omp;
    
//    // C?u hình DRI 16x16 (Kh?p v?i file .coe n?p trong BRAM)
//    reg [7:0] N_cols  = 8'd255; 
//    reg [5:0] M_rows  = 6'd15;  
//    reg [4:0] K_limit = 5'd16;

//    // Output quan sát t? DUT
//    wire [7:0] last_lambda;
//    wire [4:0] iteration_cnt;
//    wire       omp_done;

//    // --- 2. M?ng ch?a chu?i Lambda Golden t? MATLAB ---
//    // Chu?i: B7, A7, C7, 32, B8, 33, 23, C8, 43, A8, 3B, 3C, 4B, 34, 3A, 2B
//    reg [7:0] matlab_ref [0:15];
//    initial begin
//        matlab_ref[0] = 8'hB7; matlab_ref[1] = 8'hA7; matlab_ref[2] = 8'hC7; matlab_ref[3] = 8'h32;
//        matlab_ref[4] = 8'hB8; matlab_ref[5] = 8'h33; matlab_ref[6] = 8'h23; matlab_ref[7] = 8'hC8;
//        matlab_ref[8] = 8'h43; matlab_ref[9] = 8'hA8; matlab_ref[10]= 8'h3B; matlab_ref[11]= 8'h3C;
//        matlab_ref[12]= 8'h4B; matlab_ref[13]= 8'h34; matlab_ref[14]= 8'h3A; matlab_ref[15]= 8'h2B;
//    end

//    // --- 3. Kh?i t?o DUT (H? th?ng OMP t?ng h?p) ---
//    // L?u ý: Module này ?ã ch?a s?n các IP BRAM n?p file .coe bên trong
//    omp_core_top #(
//        .DW(DW),
//        .MAX_K(MAX_K)
//    ) uut (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start_omp(start_omp),
//        .N_cols(N_cols),
//        .M_rows(M_rows),
//        .K_limit(K_limit),
//        .last_lambda(last_lambda),
//        .iteration_cnt(iteration_cnt),
//        .omp_done(omp_done)
//    );

//    // --- 4. T?o xung Clock ---
//    initial clk = 0;
//    always #(PERIOD/2) clk = ~clk;

//    // --- 5. Ti?n trình ?i?u khi?n chính ---
//    integer err_count = 0;
//    initial begin
//        // Reset h? th?ng
//        rst_n = 0;
//        start_omp = 0;
//        #(PERIOD * 20);
//        rst_n = 1;
//        #(PERIOD * 10);

//        $display("\n==================================================");
//        $display("   BAT DAU MO PHONG OMP CORE TOP (DU LIEU THAT)");
//        $display("==================================================\n");

//        // Kích ho?t h? th?ng
//        @(posedge clk);
//        start_omp = 1;
//        @(posedge clk);
//        start_omp = 0;

//        // Ch? tín hi?u k?t thúc sau 16 vòng l?p
//        wait(omp_done);
        
//        #(PERIOD * 100);
//        $display("\n==================================================");
//        $display("MO PHONG KET THUC TAI %t", $time);
//        $display("Tong so loi sai lech (Mismatches): %0d", err_count);
//        if (err_count == 0)
//            $display("TRANG THAI: THANH CONG TUYET DOI (PERFECT CONVERGENCE)");
//        else
//            $display("TRANG THAI: CO LOI SAI SO - CAN KIEM TRA PIPELINE");
//        $display("==================================================\n");
//        $finish;
//    end

//    // --- 6. LOGIC KI?M TRA T? ??NG (Fix l?i sample s?m/xx) ---
//    integer k;
//    real alpha_val;

//    initial begin
//        for (k = 0; k < 16; k = k + 1) begin
//            // B??c 1: ??i FSM t?ng nh?y vào tr?ng thái ch?t Lambda (State 5)
//            wait(uut.state == 4'd5);
            
//            // B??c 2: ??i thêm 1 nh?p clock ?? last_lambda c?p nh?t xong t? lambda_bus
//            @(posedge clk);
//            #1; // ??m 1ns ?n ??nh
            
//            // Soi giá tr? Alpha t?i vòng l?p này ?? ki?m tra h?i t?
//            alpha_val = $itor($signed(uut.u_block_b2.alpha_reg)) / 8192.0;

//            $display("ITERATION %0d (Lambda HW: %d / Hex: %h)", k, last_lambda, last_lambda);
//            $display("  Alpha (Correlation Coefficient): %f", alpha_val);
            
//            if (last_lambda === matlab_ref[k]) begin
//                $display("  >>> [MATCHED] Khop voi MATLAB Golden");
//            end else begin
//                $display("  >>> [FAIL] Sai lech! MATLAB mong doi: %h", matlab_ref[k]);
//                err_count = err_count + 1;
//            end
//            $display("-----------------------------------");

//            // B??c 3: ??i cho ??n khi FSM thoát kh?i tr?ng thái LATCH ?? không check trùng
//            wait(uut.state != 4'd5);
//        end
//    end

//    // Giám sát k?t (Timeout Safety)
//    initial begin
//        #5_000_000; // 5ms
//        if (!omp_done) begin
//            $display("\n[TIMEOUT] He thong bi treo tai Iteration %0d!", iteration_cnt);
//            $finish;
//        end
//    end

//endmodule

`timescale 1ns / 1ps

module tb_omp_core_top();

    // --- 1. Tham s? h? th?ng ---
    parameter DW = 24;
    parameter PERIOD = 10; // 100 MHz
    parameter MAX_K = 16;

    reg clk;
    reg rst_n;
    reg start_omp;
    
    // C?u hình DRI 16x16 (Kh?p v?i file .coe n?p trong BRAM)
    reg [7:0] N_cols  = 8'd255; 
    reg [5:0] M_rows  = 6'd15;  
    reg [4:0] K_limit = 5'd16;

    // Output quan sát t? DUT
    wire [7:0] last_lambda;
    wire [4:0] iteration_cnt;
    wire       omp_done;

    // --- 2. M?ng ch?a chu?i Lambda Golden t? MATLAB ---
    // Chu?i: B7, A7, C7, 32, B8, 33, 23, C8, 43, A8, 3B, 3C, 4B, 34, 3A, 2B
    reg [7:0] matlab_ref [0:15];
    initial begin
        matlab_ref[0] = 8'hB7; matlab_ref[1] = 8'hA7; matlab_ref[2] = 8'hC7; matlab_ref[3] = 8'h32;
        matlab_ref[4] = 8'hB8; matlab_ref[5] = 8'h33; matlab_ref[6] = 8'h23; matlab_ref[7] = 8'hC8;
        matlab_ref[8] = 8'h43; matlab_ref[9] = 8'hA8; matlab_ref[10]= 8'h3B; matlab_ref[11]= 8'h3C;
        matlab_ref[12]= 8'h4B; matlab_ref[13]= 8'h34; matlab_ref[14]= 8'h3A; matlab_ref[15]= 8'h2B;
    end

    // --- 3. Kh?i t?o DUT (H? th?ng OMP t?ng h?p) ---
    // L?u ý: Module này ?ã ch?a s?n các IP BRAM n?p file .coe bên trong
    omp_core_top #(
        .DW(DW),
        .MAX_K(MAX_K)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_omp(start_omp),
        .N_cols(N_cols),
        .M_rows(M_rows),
        .K_limit(K_limit),
        .last_lambda(last_lambda),
        .iteration_cnt(iteration_cnt),
        .omp_done(omp_done)
    );

    // --- 4. T?o xung Clock ---
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

    // --- 5. Ti?n trình ?i?u khi?n chính ---
    integer err_count = 0;
    initial begin
        // Reset h? th?ng
        rst_n = 0;
        start_omp = 0;
        #(PERIOD * 20);
        rst_n = 1;
        #(PERIOD * 10);

        $display("\n==================================================");
        $display("   BAT DAU MO PHONG OMP CORE TOP (DU LIEU THAT)");
        $display("==================================================\n");

        // Kích ho?t h? th?ng
        @(posedge clk);
        start_omp = 1;
        @(posedge clk);
        start_omp = 0;

        // Ch? tín hi?u k?t thúc sau 16 vòng l?p
        wait(omp_done);
        
        #(PERIOD * 100);
        $display("\n==================================================");
        $display("MO PHONG KET THUC TAI %t", $time);
        $display("Tong so loi sai lech (Mismatches): %0d", err_count);
        if (err_count == 0)
            $display("TRANG THAI: THANH CONG TUYET DOI (PERFECT CONVERGENCE)");
        else
            $display("TRANG THAI: CO LOI SAI SO - CAN KIEM TRA PIPELINE");
        $display("==================================================\n");
        $finish;
    end

    // --- 6. LOGIC KI?M TRA T? ??NG (Fix l?i sample s?m/xx) ---
    integer k;
    real alpha_val;

    initial begin
        for (k = 0; k < 16; k = k + 1) begin
            // B??c 1: ??i FSM t?ng nh?y vào tr?ng thái ch?t Lambda (State 5)
            wait(uut.state == 4'd5);
            
            // B??c 2: ??i thêm 1 nh?p clock ?? last_lambda c?p nh?t xong t? lambda_bus
            @(posedge clk);
            #1; // ??m 1ns ?n ??nh
            
            // Soi giá tr? Alpha t?i vòng l?p này ?? ki?m tra h?i t?
            alpha_val = $itor($signed(uut.u_block_b2.alpha_reg)) / 8192.0;

            $display("ITERATION %0d (Lambda HW: %d / Hex: %h)", k, last_lambda, last_lambda);
            $display("  Alpha (Correlation Coefficient): %f", alpha_val);
            
            if (last_lambda === matlab_ref[k]) begin
                $display("  >>> [MATCHED] Khop voi MATLAB Golden");
            end else begin
                $display("  >>> [FAIL] Sai lech! MATLAB mong doi: %h", matlab_ref[k]);
                err_count = err_count + 1;
            end
            $display("-----------------------------------");

            // B??c 3: ??i cho ??n khi FSM thoát kh?i tr?ng thái LATCH ?? không check trùng
            wait(uut.state != 4'd5);
        end
    end

    // Giám sát k?t (Timeout Safety)
    initial begin
        #5_000_000; // 5ms
        if (!omp_done) begin
            $display("\n[TIMEOUT] He thong bi treo tai Iteration %0d!", iteration_cnt);
            $finish;
        end
    end

endmodule
