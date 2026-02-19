`timescale 1ns / 1ps

module tb_real_data_check();
    reg clk, rst_n, start_test;
    wire test_done;
    wire [23:0] alpha;
    wire [55:0] energy_u;

    qr_mgs_bram_test_wrapper dut (
        .clk(clk), .rst_n(rst_n), .start_test(start_test),
        .lambda_in(8'd183), .current_i(5'd0),
        .test_done(test_done), .out_alpha(alpha), .out_u(energy_u)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; start_test = 0;
        #100 rst_n = 1; #100;
        
        $display("--- BAT DAU TEST VOI LAMBDA 183 ---");
        start_test = 1;
        #10 start_test = 0;
        
        wait(test_done);
        #100;
        $display("--- KET QUA ---");
        $display("Energy u (Hex): %h", energy_u);
        $display("Alpha (Hex):    %h", alpha);
        $finish;
    end
endmodule