`timescale 1ns / 1ps

module tb_fast_isr;

    // --- Parameters ---
    parameter IN_W  = 56;
    parameter OUT_W = 24;

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg start;
    reg [IN_W-1:0] u_in;

    wire [OUT_W-1:0] y_out;
    wire done;

    // --- DUT Instantiation ---
    fast_isr #(
        .IN_W(IN_W),
        .OUT_W(OUT_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .u_in(u_in),
        .y_out(y_out),
        .done(done)
    );

    // --- Clock Generation (100 MHz) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Task: Run one test case ---
    // u_hex: giá tr? ??u vào u (Qxx.26)
    // expected_msg: tin nh?n hi?n th?
    task run_test(input [IN_W-1:0] u_hex, input reg [127:0] msg);
        begin
            u_in = u_hex;
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            // ??i tín hi?u done (Newton-Raphson t?n kho?ng 7 chu k?)
            wait(done);
            #1; // ??i c?p nh?t tín hi?u cu?i
            
            $display("[%t] TEST %s:", $time, msg);
            $display("    Input u      : %h (Real: %f)", u_in, $itor(u_in) / (2**26));
            $display("    Output y_out : %h (Q2.22)", y_out);
            $display("    Real 1/sqrt  : %f", $itor(y_out) / (2**22));
            $display("    Theoretical  : %f", 1.0 / $sqrt($itor(u_in) / (2**26)));
            $display("---------------------------------------");
            #50;
        end
    endtask

    // --- Stimulus ---
    initial begin
        // 1. Reset h? th?ng
        rst_n = 0;
        start = 0;
        u_in = 0;
        #100;
        rst_n = 1;
        #50;

        $display("--- BAT DAU MO PHONG FAST ISR (NEWTON-RAPHSON) ---");

        // Test Case 1: u = 1.0 (Bit 26 là 1)
        // K? v?ng: 1/sqrt(1) = 1.0 -> Hex 400000 (Q22)
        run_test(56'h00000004000000, "u = 1.0");

        // Test Case 2: u = 4.0 (Bit 28 là 1)
        // K? v?ng: 1/sqrt(4) = 0.5 -> Hex 200000 (Q22)
        run_test(56'h00000010000000, "u = 4.0");

        // Test Case 3: u = 0.25 (Bit 24 là 1)
        // K? v?ng: 1/sqrt(0.25) = 2.0 -> Hex 800000 (Q22)
        run_test(56'h00000001000000, "u = 0.25");

        // Test Case 4: u = 2.0 (Bit 27 là 1)
        // K? v?ng: 1/sqrt(2) = 0.7071 -> Hex 2D413D
        run_test(56'h00000008000000, "u = 2.0");

        // Test Case 5: u = 0.5
        // K? v?ng: 1/sqrt(0.5) = 1.4142 -> Hex 5A8279
        run_test(56'h00000002000000, "u = 0.5");

        // Test Case 6: u c?c l?n (Sát biên bão hòa LUT)
        run_test(56'h0000003FFFFFFF, "u max value");

        #200;
        $display("--- MO PHONG HOAN TAT ---");
        $finish;
    end

endmodule