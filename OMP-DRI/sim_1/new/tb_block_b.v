`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 09:03:39 PM
// Design Name: 
// Module Name: tb_block_b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////




module tb_block_b();

    // --- 1. Khai báo các thanh ghi ?i?u khi?n ??u vào ---
    reg clk;
    reg rst_n;
    reg start_b;
    reg [5:0] lambda;
    reg [4:0] current_i;
    reg [2:0] M_limit;

    // --- 2. Khai báo các dây nh?n ??u ra ---
    wire done_b;

    // --- 3. G?i module Top Test Block B t??ng minh ---
    top_test_block_b dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_b(start_b),
        .lambda(lambda),
        .current_i(current_i),
        .M_limit(M_limit),
        .done_b(done_b)
    );

    // --- 4. T?o xung Clock 50MHz (20ns) ---
    always #10 clk = ~clk;

    // --- 5. K?ch b?n ki?m tra DRI và Gram-Schmidt ---
    initial begin
        // Kh?i t?o h? th?ng
        clk = 0;
        rst_n = 0;
        start_b = 0;
        lambda = 0;
        current_i = 0;
        M_limit = 7; // M?c ??nh ch?y 8x8 (8 dòng BRAM m?i c?t)

        #100 rst_n = 1;
        #100;

        $display("-----------------------------------------------------");
        $display("STARTING BLOCK B (MGS) TEST WITH DRI SUPPORT");
        $display("-----------------------------------------------------");

        // --- VÒNG L?P i = 0 ---
        $display("Time: %t | Iteration 0: Loading Lambda 39", $time);
        lambda = 39;
        current_i = 0;
        #20 start_b = 1; #20 start_b = 0;
        wait(done_b);
        $display("Time: %t | Iteration 0 DONE. Q[0] and U[0,0] stored.", $time);
        
        #500; // Kho?ng ngh? gi?a các ??t ch?y

        // --- VÒNG L?P i = 1 ---
        $display("Time: %t | Iteration 1: Loading Lambda 4", $time);
        lambda = 4;
        current_i = 1;
        #20 start_b = 1; #20 start_b = 0;
        wait(done_b);
        $display("Time: %t | Iteration 1 DONE. Q[1] and U[0:1,1] stored.", $time);

        #500;

        // --- VÒNG L?P i = 2 (Thêm ?? test tính tr?c giao sâu h?n) ---
        $display("Time: %t | Iteration 2: Loading Lambda 27", $time);
        lambda = 27;
        current_i = 2;
        #20 start_b = 1; #20 start_b = 0;
        wait(done_b);
        $display("Time: %t | Iteration 2 DONE. Q[2] and U[0:2,2] stored.", $time);

        #200;
        $display("-----------------------------------------------------");
        $display("BLOCK B MGS TEST COMPLETED SUCCESSFULLY");
        $display("-----------------------------------------------------");
        $stop;
    end

    // --- 6. T? ??ng ki?m tra tín hi?u Ghi vào BRAM U (Monitor) ---
    always @(posedge clk) begin
        if (dut.uut_b.u_we) begin
            $display("DEBUG BRAM U | Time: %t | Addr: %d | Data: %h", 
                     $time, dut.uut_b.u_addr, dut.uut_b.u_wdata);
        end
    end

endmodule
