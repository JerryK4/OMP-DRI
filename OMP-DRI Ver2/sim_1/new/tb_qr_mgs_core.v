`timescale 1ns / 1ps

module tb_qr_mgs_core;

    // --- Parameters ---
    parameter DW = 24;          // Q10.13
    parameter ADDR_W_PHI = 12;  // 4096 rows
    parameter ADDR_W_Q = 8;     // 256 rows
    parameter DOT_W = 56;

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg start_core;
    reg [7:0] lambda_i;
    reg [4:0] current_i;

    wire [ADDR_W_PHI-1:0] phi_addr;
    reg  [95:0]           phi_data_reg;
    wire [7:0]            r_addr_a;
    wire                  r_we_a;
    wire [23:0]           r_din_a;
    wire [ADDR_W_Q-1:0]   q_addr_a;
    wire                  q_we_a;
    wire [95:0]           q_din_a;
    wire [ADDR_W_Q-1:0]   q_addr_b;
    reg  [95:0]           q_dout_b_reg;

    wire core_done;

    // --- RAM Models (Simulating BRAM Latency-1) ---
    reg [95:0] mem_phi [0:4095];
    reg [95:0] mem_q   [0:255];
    reg [23:0] mem_r   [0:255];

    // --- DUT Instantiation ---
    qr_mgs_core #(
        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start_core(start_core),
        .lambda_i(lambda_i), .current_i(current_i), .M_rows_in(4'd15),
        .phi_addr(phi_addr), .phi_data(phi_data_reg),
        .r_addr_a(r_addr_a), .r_we_a(r_we_a), .r_din_a(r_din_a),
        .q_addr_a(q_addr_a), .q_we_a(q_we_a), .q_din_a(q_din_a),
        .q_addr_b(q_addr_b), .q_dout_b(q_dout_b_reg),
        .core_done(core_done)
    );

    // --- Clock Gen (100MHz) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- BRAM Port Emulation ---
    always @(posedge clk) begin
        phi_data_reg <= mem_phi[phi_addr];
        q_dout_b_reg <= mem_q[q_addr_b];
        if (q_we_a) mem_q[q_addr_a] <= q_din_a;
        if (r_we_a) mem_r[r_addr_a] <= r_din_a;
    end

    // --- Bi?n h? tr? ki?m tra sai s? ---
    real q0_real [0:63], q1_real [0:63];
    real dot_product_check, hw_val;
    integer r, c, i;

    // --- Stimulus ---
    initial begin
        // 1. Kh?i t?o
        rst_n = 0; start_core = 0; lambda_i = 0; current_i = 0;
        for (i=0; i<4096; i=i+1) mem_phi[i] = 0;
        for (i=0; i<256; i=i+1) begin mem_q[i] = 0; mem_r[i] = 0; end
        #100 rst_n = 1; #50;

        $display("==========================================================");
        $display("   KIEM TRA QR-MGS CORE: CHUAN HOA & TRUC GIAO HOA");
        $display("==========================================================");

        // --- TEST 1: CHU?N HÓA (Iteration 0) ---
        // N?p vector Phi(0) = [0.25, 0.25, ...] (Q13: 000800)
        // K? v?ng Q0 = [0.125, 0.125, ...] (Q13: 000400)
        for (r=0; r<16; r=r+1) mem_phi[0*16 + r] = {4{24'h000800}};

        lambda_i = 0; current_i = 0;
        @(posedge clk); start_core = 1;
        @(posedge clk); start_core = 0;
        wait(core_done); #20;

        hw_val = $itor($signed(mem_q[0][23:0])) / 8192.0;
        $display("[ITER 0] Check Normalization:");
        $display("   -> Hardware Q0[0] = %f (Hex: %h)", hw_val, mem_q[0][23:0]);
        if (mem_q[0][23:0] >= 24'h0003F0 && mem_q[0][23:0] <= 24'h000410)
            $display("   >>> STATUS: PASSED");
        else
            $display("   >>> STATUS: FAILED (Check ISR logic)");

        // --- TEST 2: TR?C GIAO HÓA (Iteration 1) ---
        // ?ã có Q0. Gi? n?p Phi(1) là vector d?c (ramp) [0.1, 0.2, 0.3...]
        // MGS s? th?c hi?n: w' = Phi(1) - <Q0, Phi(1)>*Q0. Sau ?ó chu?n hóa w' -> Q1
        for (r=0; r<16; r=r+1) begin
            mem_phi[1*16 + r] = {24'h000200 + r*4, 24'h000200 + r*4 + 1, 
                                 24'h000200 + r*4 + 2, 24'h000200 + r*4 + 3};
        end

        lambda_i = 1; current_i = 1;
        @(posedge clk); start_core = 1;
        @(posedge clk); start_core = 0;
        wait(core_done); #20;

        $display("\n[ITER 1] Check Orthogonality:");
        // Tính tích vô h??ng <Q0, Q1> b?ng s? th?c ?? ki?m tra
        dot_product_check = 0;
        for (r=0; r<16; r=r+1) begin
            for (c=0; c<4; c=c+1) begin
                dot_product_check = dot_product_check + 
                    ($itor($signed(mem_q[0*16+r][c*24 +: 24]))/8192.0) * 
                    ($itor($signed(mem_q[1*16+r][c*24 +: 24]))/8192.0);
            end
        end
        $display("   -> Dot Product <Q0, Q1> = %f", dot_product_check);
        
        if (dot_product_check < 0.005 && dot_product_check > -0.005)
            $display("   >>> STATUS: PASSED (Q0 and Q1 are orthogonal)");
        else
            $display("   >>> STATUS: FAILED (Q0 and Q1 are not orthogonal)");

        $display("==========================================================");
        $finish;
    end

endmodule