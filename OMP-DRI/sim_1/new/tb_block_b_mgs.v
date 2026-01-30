`timescale 1ns / 1ps

module tb_block_b_mgs();

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg start_b;
    reg [5:0] lambda;
    reg [4:0] current_i;
    reg [2:0] M_limit;

    wire [8:0] phi_addr;
    reg  [95:0] phi_data;

    wire [6:0] q_addr;
    wire [95:0] q_wdata;
    wire q_we;
    reg  [95:0] q_rdata;

    wire [2:0] r_addr;
    wire [95:0] r_wdata;
    wire r_we;
    reg  [95:0] r_rdata;

    wire [5:0] u_addr;
    wire [95:0] u_wdata;
    wire u_we;
    wire done_b;

    // --- Instantiate UUT ---
    block_b_mgs uut (
        .clk(clk), .rst_n(rst_n), .start_b(start_b),
        .lambda(lambda), .current_i(current_i), .M_limit(M_limit),
        .phi_addr(phi_addr), .phi_data(phi_data),
        .q_addr(q_addr), .q_wdata(q_wdata), .q_we(q_we), .q_rdata(q_rdata),
        .r_addr(r_addr), .r_wdata(r_wdata), .r_we(r_we), .r_rdata(r_rdata),
        .u_addr(u_addr), .u_wdata(u_wdata), .u_we(u_we),
        .done_b(done_b)
    );

    // --- Clock Generation ---
    always #10 clk = ~clk;

    // --- Mock BRAM Logic (1 cycle delay) ---
    // Gi? l?p d? li?u cho Phi: tr? v? chính ??a ch? ?? d? track
    always @(posedge clk) begin
        phi_data <= { {15'd0, phi_addr}, {15'd0, phi_addr}, {15'd0, phi_addr}, {15'd0, phi_addr} };
        
        // Gi? l?p Q_rdata (?? test vòng l?p j)
        // Khi i=1, j=0, q_addr s? quét 0-7. Tr? v? giá tr? 0.1 (hex 000333)
        q_rdata  <= {24'h000333, 24'h000333, 24'h000333, 24'h000333};
        
        // Gi? l?p R_rdata cho b??c Update R
        r_rdata  <= {24'h002000, 24'h002000, 24'h002000, 24'h002000};
    end

    // --- Test Scenarios ---
    initial begin
        // Init
        clk = 0; rst_n = 0; start_b = 0;
        lambda = 0; current_i = 0; M_limit = 7; // Ch? ?? 8x8

        #100 rst_n = 1; #50;

        // CASE 1: L?n l?p ??u tiên (i = 0)
        // H? th?ng n?p phi, skip loop j, tính U00, chu?n hóa Q0, update R.
        $display("Time: %t | START: Iteration i=0, Lambda=10", $time);
        lambda = 10; current_i = 0; M_limit = 7;
        #20 start_b = 1; #20 start_b = 0;

        wait(done_b);
        $display("Time: %t | DONE: Iteration i=0 finished", $time);

        #500;

        // CASE 2: L?n l?p th? hai (i = 1)
        // S? ch?y vòng l?p j=0 (tr?c giao hóa v?i Q0 v?a n?p)
        $display("Time: %t | START: Iteration i=1, Lambda=20", $time);
        lambda = 20; current_i = 1; M_limit = 7;
        #20 start_b = 1; #20 start_b = 0;

        wait(done_b);
        $display("Time: %t | DONE: Iteration i=1 finished", $time);

        #200;
        $display(">>> ALL BLOCK B TESTS FINISHED <<<");
        $stop;
    end

    // --- Monitor BRAM U (H? s? ma tr?n) ---
    always @(posedge clk) begin
        if (u_we)
            $display("Time: %t | BRAM U WRITE | Addr: %d | Data: %h", $time, u_addr, u_wdata);
    end

endmodule