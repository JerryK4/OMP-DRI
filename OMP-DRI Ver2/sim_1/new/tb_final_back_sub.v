`timescale 1ns / 1ps

module tb_final_back_sub;
    reg clk, rst_n, start_bs;
    reg [767:0] v_in_flat;
    wire [7:0] r_addr;
    reg [23:0] r_dout_reg;
    
    wire [23:0] x_hat_val;
    wire [3:0]  x_hat_idx;
    wire x_hat_valid, bs_done;

    reg [23:0] mem_r [0:255];

    final_back_sub dut (
        .clk(clk), .rst_n(rst_n), .start_bs(start_bs),
        .v_in_flat(v_in_flat), .r_addr(r_addr), .r_dout(r_dout_reg),
        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx),
        .x_hat_valid(x_hat_valid), .bs_done(bs_done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // RAM Latency-1
    always @(posedge clk) r_dout_reg <= mem_r[r_addr];

    integer i, k;
    initial begin
        rst_n = 0; start_bs = 0; v_in_flat = 0;
        for(i=0; i<256; i=i+1) mem_r[i] = 0;
        
        // 1. Gi? l?p ma tr?n R ??n v?: R(i,i) = 1.0 (ISR Q2.22 = 400000h)
        for(i=0; i<16; i=i+1) mem_r[(i<<4)+i] = 24'h400000;
        
        // 2. N?p vector v = 32.0 vào bus 768-bit (Q26 = 80000000h)
        for(k=0; k<16; k=k+1) v_in_flat[k*48 +: 48] = 48'h000080000000;

        #100 rst_n = 1; #50;
        
        $display("--- TEST BACK-SUBSTITUTION: R*x = v ---");
        @(posedge clk); start_bs = 1;
        @(posedge clk); start_bs = 0;
        
        // Giám sát d? li?u serial ??y ra
        $display("Index |  Hex Val | Real Val");
        forever begin
            @(posedge clk);
            if (x_hat_valid) begin
                $display("  %0d   |  %h  | %f", x_hat_idx, x_hat_val, $itor($signed(x_hat_val))/8192.0);
                if (x_hat_idx == 15) begin
                    if (x_hat_val == 24'h040000) $display(">>> STATUS: PASSED");
                    else                         $display(">>> STATUS: FAILED (Expected 040000)");
                    #20 $finish;
                end
            end
        end
    end
endmodule