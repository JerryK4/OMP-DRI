`timescale 1ns / 1ps

module tb_atom_selection_system_final;
    reg clk;
    reg rst_n;
    reg start;
    reg [4:0] current_i;
    reg [143:0] lambda_history;

    wire [7:0] lambda_out;
    wire atom_done;

    // Kh?i t?o DUT
    atom_selection_system_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .current_i(current_i),
        .lambda_history(lambda_history),
        .lambda_out(lambda_out),
        .atom_done(atom_done)
    );

    // Clock 100MHz
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Reset h? th?ng
        rst_n = 0;
        start = 0;
        current_i = 0;
        lambda_history = 0;
        #100;
        rst_n = 1;
        #50;

        $display("[%t] >>> BAT DAU TEST VOI DU LIEU THUC TU BRAM...", $time);
        
        // Kích ho?t Atom Selection
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // ??i k?t qu? t? ph?n c?ng
        wait(atom_done);
        #20;
        
        $display("[%t] KET QUA TU BRAM: Lambda Out = %d (Hex: %h)", $time, lambda_out, lambda_out);
        
        if (lambda_out == 8'd183) 
            $display(">>> CHUC MUNG! Ket qua he thong KHOP voi MATLAB.");
        else 
            $display(">>> CANH BAO! Ket qua (%d) khac MATLAB. Kiem tra lai file .coe!", lambda_out);

        #500;
        $finish;
    end
endmodule