//`timescale 1ns / 1ps

//module tb_final_estimation_system;

//    // --- Parameters ---
//    parameter DW = 24;

//    // --- Signals ---
//    reg clk;
//    reg rst_n;
//    reg start_est;
    
//    // Memory Interfaces
//    wire [3:0]  y_addr;
//    reg  [95:0] y_dout_reg;
//    wire [7:0]  q_addr;
//    reg  [95:0] q_dout_reg;
//    wire [7:0]  r_addr;
//    reg  [23:0] r_dout_reg;

//    // Outputs
//    wire [23:0] x_hat_val;
//    wire [3:0]  x_hat_idx;
//    wire        x_hat_valid;
//    wire        done_all;

//    // --- Simulated BRAMs ---
//    reg [95:0] mem_y [0:15];   
//    reg [95:0] mem_q [0:255];  
//    reg [23:0] mem_r [0:255];  

//    // --- DUT Instantiation ---
//    final_estimation_top dut (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start_est(start_est),
//        .y_addr(y_addr),
//        .y_dout(y_dout_reg),
//        .q_addr(q_addr),
//        .q_dout(q_dout_reg),
//        .r_addr(r_addr),
//        .r_dout(r_dout_reg),
//        .x_hat_val(x_hat_val),
//        .x_hat_idx(x_hat_idx),
//        .x_hat_valid(x_hat_valid),
//        .done_all(done_all)
//    );

//    // --- Clock Generation ---
//    initial clk = 0;
//    always #5 clk = ~clk;

//    // --- RAM Latency-1 Simulation ---
//    always @(posedge clk) begin
//        y_dout_reg <= mem_y[y_addr];
//        q_dout_reg <= mem_q[q_addr];
//        r_dout_reg <= mem_r[r_addr];
//    end

//    // --- KH?I 1: ?I?U KHI?N MÔ PH?NG ---
//    integer i;
//    initial begin
//        // 1. Kh?i t?o ban ??u
//        rst_n = 0; start_est = 0;
//        for(i=0; i<256; i=i+1) begin
//            if(i < 16) mem_y[i] = 96'd0;
//            mem_q[i] = 96'd0; mem_r[i] = 24'd0;
//        end

//        // 2. N?P ?? D? LI?U CHO 16 C?T
//        // Vector y = toàn s? 1.0 (Q13: 002000h)
//        for(i=0; i<16; i=i+1) mem_y[i] = {4{24'h002000}};
        
//        // Ma tr?n Q: N?p T?T C? 16 c?t ??u là 0.5 (001000h)
//        for(i=0; i<256; i=i+1) begin
//            mem_q[i] = {24'h001000, 24'h001000, 24'h001000, 24'h001000};
//        end
        
//        // Ma tr?n R: Gi? s? là ma tr?n ??n v? (Rii = 1.0)
//        for(i=0; i<16; i=i+1) mem_r[(i<<4)+i] = 24'h400000;

//        #100; rst_n = 1; #50;
        
//        // Kích ho?t gi?i mã
//        @(posedge clk); start_est = 1;
//        @(posedge clk); start_est = 0;

//        // ??i tín hi?u xong
//        wait(done_all);
//        #100;
//        $display("===========================================================");
//        $display("   MO PHONG HOAN TAT");
//        $display("===========================================================");
//        $finish;
//    end

//    // --- KH?I 2: GIÁM SÁT D? LI?U ??U RA ---
//    initial begin
//        wait(rst_n);
//        $display("Index | Hardware Hex | Real Value | Status");
//        $display("------|--------------|------------|-------");
//        forever begin
//            @(posedge clk);
//            if (x_hat_valid) begin
//                $display("  %2d  |    %h    |  %f  | %s", 
//                        x_hat_idx, x_hat_val, 
//                        $itor($signed(x_hat_val))/8192.0,
//                        (x_hat_val == 24'h040000) ? "MATCH" : "ERROR");
//            end
//        end
//    end

//    // --- KH?I 3: B? GIÁM SÁT TH?I GIAN (TIMEOUT) ---
//    initial begin
//        #100000; // 100us
//        $display("TIMEOUT: Mo phong qua lau, co the bi ket FSM!");
//        $finish;
//    end

//endmodule


`timescale 1ns / 1ps

module tb_final_estimation_system;

    parameter DW = 24;
    reg clk;
    reg rst_n;
    reg start_est;
    
    // Memory Interfaces
    wire [3:0]  y_addr;
    reg  [95:0] y_dout_reg;
    wire [7:0]  q_addr;
    reg  [95:0] q_dout_reg;
    wire [7:0]  r_addr;
    reg  [23:0] r_dout_reg;

    // Outputs
    wire [23:0] x_hat_val;
    wire [3:0]  x_hat_idx;
    wire        x_hat_valid;
    wire        done_all;

    // Simulated BRAMs
    reg [95:0] mem_y [0:15];   
    reg [95:0] mem_q [0:255];  
    reg [23:0] mem_r [0:255];  

    // Bi?n ?? tính toán Golden Model (S? th?c)
    real y_real [0:63];
    real q_real [0:63][0:15];
    real r_real [0:15][0:15];
    real v_real [0:15];
    real x_expected [0:15];
    real tolerance = 0.005; // Ng??ng sai s? cho phép (~0.5%)

    final_estimation_top dut (
        .clk(clk), .rst_n(rst_n), .start_est(start_est),
        .y_addr(y_addr), .y_dout(y_dout_reg),
        .q_addr(q_addr), .q_dout(q_dout_reg),
        .r_addr(r_addr), .r_dout(r_dout_reg),
        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid), .done_all(done_all)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        y_dout_reg <= mem_y[y_addr];
        q_dout_reg <= mem_q[q_addr];
        r_dout_reg <= mem_r[r_addr];
    end

    // --- KH?I 1: KH?I T?O D? LI?U PH?C T?P ---
    integer i, j, row, col;
    initial begin
        rst_n = 0; start_est = 0;
        
        // 1. T?o d? li?u th?c cho vector y: y_k = 0.5 + 0.02*k
        for (i=0; i<64; i=i+1) begin
            y_real[i] = 0.5 + (0.02 * i);
            // N?p vào BRAM y (4 ph?n t? m?i hàng)
            if (i%4 == 0) mem_y[i/4][23:0]   = $rtoi(y_real[i] * 8192);
            if (i%4 == 1) mem_y[i/4][47:24]  = $rtoi(y_real[i] * 8192);
            if (i%4 == 2) mem_y[i/4][71:48]  = $rtoi(y_real[i] * 8192);
            if (i%4 == 3) mem_y[i/4][95:72]  = $rtoi(y_real[i] * 8192);
        end

        // 2. T?o Ma tr?n Q: Gi? l?p t?p c? s? tr?c giao (??n gi?n hóa ?? test MAC)
        for (col=0; col<16; col=col+1) begin
            for (row=0; row<64; row=row+1) begin
                if (row/4 == col) q_real[row][col] = 0.8; // C?t col có giá tr? t?i 4 hàng t??ng ?ng
                else              q_real[row][col] = 0.01;
                
                // N?p vào BRAM q
                if (row%4 == 0) mem_q[(col<<4) + row/4][23:0]  = $rtoi(q_real[row][col] * 8192);
                if (row%4 == 1) mem_q[(col<<4) + row/4][47:24] = $rtoi(q_real[row][col] * 8192);
                if (row%4 == 2) mem_q[(col<<4) + row/4][71:48] = $rtoi(q_real[row][col] * 8192);
                if (row%4 == 3) mem_q[(col<<4) + row/4][95:72] = $rtoi(q_real[row][col] * 8192);
            end
        end

        // 3. T?o Ma tr?n R tam giác trên
        for (i=0; i<16; i=i+1) begin
            for (j=0; j<16; j=j+1) begin
                if (i == j) begin
                    r_real[i][j] = 1.25; // R_ii th?c t?
                    mem_r[(j<<4)+i] = $rtoi((1.0/1.25) * 4194304); // L?u ISR (Q22) vào BRAM
                end else if (j > i) begin
                    r_real[i][j] = 0.1; // H? s? Rij
                    mem_r[(j<<4)+i] = $rtoi(r_real[i][j] * 8192); // L?u Q13 vào BRAM
                end else begin
                    r_real[i][j] = 0;
                end
            end
        end

        // 4. TÍNH TOÁN GOLDEN RESULT (Lý thuy?t)
        // B1: v = Q^T * y
        for (i=0; i<16; i=i+1) begin
            v_real[i] = 0;
            for (row=0; row<64; row=row+1) v_real[i] = v_real[i] + q_real[row][i] * y_real[row];
        end
        // B2: Gi?i ng??c R*x = v
        for (i=15; i>=0; i=i-1) begin
            x_expected[i] = v_real[i];
            for (j=15; j>i; j=j-1) x_expected[i] = x_expected[i] - r_real[i][j] * x_expected[j];
            x_expected[i] = x_expected[i] / r_real[i][i];
        end

        #100; rst_n = 1; #50;
        $display("--- BAT DAU MO PHONG FINAL ESTIMATION NANG CAO ---");
        @(posedge clk); start_est = 1;
        @(posedge clk); start_est = 0;

        wait(done_all);
        #100;
        $display("--- MO PHONG HOAN TAT ---");
        $finish;
    end

    // --- KH?I 2: KI?M TRA SAI S? T? ??NG ---
    real current_hw_val;
    real current_error;
    initial begin
        wait(rst_n);
        $display("Index | HW Value | Expected | Error Status");
        $display("------|----------|----------|-------------");
        forever begin
            @(posedge clk);
            if (x_hat_valid) begin
                current_hw_val = $itor($signed(x_hat_val)) / 8192.0;
                current_error = current_hw_val - x_expected[x_hat_idx];
                if (current_error < 0) current_error = -current_error;

                $write("  %2d  | %f | %f |", x_hat_idx, current_hw_val, x_expected[x_hat_idx]);
                if (current_error < tolerance) $display(" [OK] (Error: %f)", current_error);
                else                           $display(" [FAIL] (Error: %f)", current_error);
            end
        end
    end

    initial begin #200000; $display("TIMEOUT!"); $finish; end

endmodule