`timescale 1ns / 1ps

module tb_omp_core_top_simple();

    // --- 1. Tham s? h? th?ng ---
    parameter DW = 24;
    parameter PERIOD = 7.24; // ~138 MHz nh? trong bài báo
    parameter MAX_K = 16;

    reg clk;
    reg rst_n;
    reg start_omp;
    
    // C?u hình DRI 16x16
    wire [7:0] N_cols  = 8'd255; 
    wire [5:0] M_rows  = 6'd15;  
    wire [4:0] K_limit = 5'd16;

    // Interface BRAM
    wire [11:0] phi_mem_addr;
    wire [95:0] phi_mem_dout;
    wire [3:0]  y_mem_addr;
    wire [95:0] y_mem_dout;

    // Output
    wire [7:0] last_lambda;
    wire [4:0] iteration_cnt;
    wire       omp_done;

    // --- 2. M?ng ch?a chu?i Lambda "Golden" t? MATLAB ?? so sánh ---
    reg [7:0] matlab_ref [0:15];
    initial begin
        // Chu?i Lambda b?n ?ã cung c?p: 183, 167, 199, 50, 184, 51, 35, 200, 67, 168, 59, 60, 75, 52, 58, 43
        matlab_ref[0] = 8'hB7; matlab_ref[1] = 8'hA7; matlab_ref[2] = 8'hC7; matlab_ref[3] = 8'h32;
        matlab_ref[4] = 8'hB8; matlab_ref[5] = 8'h33; matlab_ref[6] = 8'h23; matlab_ref[7] = 8'hC8;
        matlab_ref[8] = 8'h43; matlab_ref[9] = 8'hA8; matlab_ref[10]= 8'h3B; matlab_ref[11]= 8'h3C;
        matlab_ref[12]= 8'h4B; matlab_ref[13]= 8'h34; matlab_ref[14]= 8'h3A; matlab_ref[15]= 8'h2B;
    end

    // --- 3. Mô ph?ng BRAM th?c t? (N?p t? file) ---
    // S? d?ng IP gi? l?p ho?c m?ng ?? n?p $readmemh
    reg [95:0] ram_phi [0:4095];
    reg [95:0] ram_y   [0:15];

    initial begin
        $display("Loading memories...");
        $readmemh("phi_k16.txt", ram_phi);
        $readmemh("y_k16.txt", ram_y);
    end

    assign phi_mem_dout = ram_phi[phi_mem_addr];
    assign y_mem_dout   = ram_y[y_mem_addr];

    // --- 4. Instantiate DUT ---
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
        .phi_mem_addr(phi_mem_addr),
        .phi_mem_dout(phi_mem_dout),
        .y_mem_addr(y_mem_addr),
        .y_mem_dout(y_mem_dout),
        .last_lambda(last_lambda),
        .iteration_cnt(iteration_cnt),
        .omp_done(omp_done)
    );

    // --- 5. Clock Gen ---
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

    // --- 6. Logic Ki?m tra T? ??ng (Auto-Checker) ---
    integer k = 0;
    integer errors = 0;
    integer log_file;

    initial begin
        log_file = $fopen("omp_hw_results.log", "w");
        rst_n = 0; start_omp = 0;
        #(PERIOD * 20);
        rst_n = 1;
        #(PERIOD * 10);

        $display("\n==================================================");
        $display("   STARTING REAL-DATA OMP HARDWARE VERIFICATION   ");
        $display("==================================================\n");

        start_omp = 1; #(PERIOD); start_omp = 0;

        // Theo dõi t?ng b??c Iteration
        for (k = 0; k < 16; k = k + 1) begin
            // ??i ??n khi FSM ch?t Lambda
            wait(uut.state == 4'd5); 
            #1; // ??i tín hi?u ?n ??nh
            
            if (last_lambda === matlab_ref[k]) begin
                $display("[SUCCESS] Iteration %0d: HW Lambda = %h | MATLAB = %h", k, last_lambda, matlab_ref[k]);
                $fdisplay(log_file, "Iter %0d: PASS", k);
            end else begin
                $display("[ERROR]   Iteration %0d: HW Lambda = %h | MATLAB = %h <--- MISMATCH!", k, last_lambda, matlab_ref[k]);
                $fdisplay(log_file, "Iter %0d: FAIL (HW:%h, Mat:%h)", k, last_lambda, matlab_ref[k]);
                errors = errors + 1;
            end
            
            // ??i b??c sang vòng l?p k? ti?p
            wait(uut.state == 4'd10); 
        end

        wait(omp_done);
        #(PERIOD * 50);

        $display("\n==================================================");
        $display("VERIFICATION COMPLETE");
        $display("Total Errors: %0d / 16", errors);
        if (errors == 0) 
            $display("STATUS: PERFECT CONVERGENCE (PSNR ~321dB candidate)");
        else 
            $display("STATUS: ACCURACY ISSUES DETECTED");
        $display("==================================================\n");

        $fclose(log_file);
        $finish;
    end

    // --- 7. Giám sát N?ng l??ng (Dành cho Debug h?i t?) ---
    real energy_val;
    always @(posedge clk) begin
        if (uut.state == 4'd3) begin // ?ang tính Atom Selection
            // ??c th?ng d? th?c t? ?ang ??y ra t? RAM
            energy_val = $itor($signed(uut.res_dout_b[23:0])) / 8192.0;
            // B?n có th? xem energy_val trên Waveform ?? th?y nó gi?m d?n v? 0
        end
    end

endmodule