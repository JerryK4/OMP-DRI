`timescale 1ns / 1ps

module tb_final_v_calc;
    parameter DW = 24;
    parameter DOT_W = 56;

    reg clk;
    reg rst_n;
    reg start_v;
    wire [3:0] y_addr;
    reg  [95:0] y_dout_reg;
    wire [7:0] q_addr;
    reg  [95:0] q_dout_reg;
    wire [767:0] v_result_flat;
    wire v_done;

    // Gi? l?p RAM th?c t?
    reg [95:0] mem_y [0:15];
    reg [95:0] mem_q [0:255];

    final_v_calc dut (
        .clk(clk), .rst_n(rst_n), .start_v(start_v),
        .y_addr(y_addr), .y_dout(y_dout_reg),
        .q_addr(q_addr), .q_dout(q_dout_reg),
        .v_result_flat(v_result_flat), .v_done(v_done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Mô ph?ng tr? RAM 1 chu k? (ZedBoard Standard)
    always @(posedge clk) begin
        y_dout_reg <= mem_y[y_addr];
        q_dout_reg <= mem_q[q_addr];
    end

    integer r;
    initial begin
        rst_n = 0; start_v = 0;
        // Kh?i t?o y = 1.0 (Hex 002000)
        for(r=0; r<16; r=r+1) mem_y[r] = {4{24'h002000}};
        // Kh?i t?o Q0 = 0.5 (Hex 001000)
        for(r=0; r<16; r=r+1) mem_q[r] = {4{24'h001000}};
        
        #100 rst_n = 1; #50;
        
        $display("--- TEST FINAL V CALC: v = Q^T * y ---");
        @(posedge clk); start_v = 1;
        @(posedge clk); start_v = 0;
        
        wait(v_done);
        #10;
        
        // Ki?m tra ph?n t? ??u tiên v[0] trong bus 768-bit
        $display("Hardware v[0] (Hex): %h", v_result_flat[47:0]);
        // Q26 conversion
        $display("Real Value v[0]    : %f (Expected: 32.0)", $itor($signed(v_result_flat[47:0])) / (2**26));
        
        if (v_result_flat[47:0] == 48'h000080000000) $display(">>> STATUS: PASSED");
        else                                         $display(">>> STATUS: FAILED");
        
        #100 $finish;
    end
endmodule