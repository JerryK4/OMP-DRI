//`timescale 1ns / 1ps

//module tb_qr_mgs_system_test_top();

//    // --- Thông s? h? th?ng ---
//    parameter DW = 24;
//    parameter ADDR_W_PHI = 12;
//    parameter ADDR_W_Q = 8;
//    parameter DOT_W = 56;
//    parameter PERIOD = 10; // 100MHz

//    reg clk;
//    reg rst_n;
//    reg start_core;
//    reg [7:0] lambda_in;
//    reg [4:0] current_i;
//    reg [3:0] M_rows;

//    wire core_done;
//    wire [DOT_W-1:0] debug_u_val;
//    wire [DW-1:0]    debug_alpha_val;
//    wire [DW-1:0]    debug_rii_val;

//    // --- Instantiate DUT ---
//    qr_mgs_system_test_top #(
//        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W)
//    ) uut (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start_core(start_core),
//        .lambda_in(lambda_in),
//        .current_i(current_i),
//        .M_rows(M_rows),
//        .core_done(core_done),
//        .debug_u_val(debug_u_val),
//        .debug_alpha_val(debug_alpha_val),
//        .debug_rii_val(debug_rii_val)
//    );

//    // --- Clock Gen ---
//    initial clk = 0;
//    always #(PERIOD/2) clk = ~clk;

//    // --- Bi?n h? tr? ki?m tra s? th?c ---
//    real real_u, real_rii, real_alpha;

//    initial begin
//        // 1. Kh?i t?o và Reset
//        rst_n = 0;
//        start_core = 0;
//        lambda_in = 0;
//        current_i = 0;
//        M_rows = 15; // 16x16
        
//        #100;
//        rst_n = 1;
//        #50;

//        $display("==========================================================");
//        $display("   TEST CASE: QR-MGS CORE WITH LAMBDA = 183 (0xB7)");
//        $display("==========================================================");

//        // --- B??C 1: KI?M TRA CHU?N HÓA (ITERATION 0) ---
//        lambda_in = 8'd183; // 0xB7
//        current_i = 5'd0;   // Vòng ??u tiên
        
//        $display("[%t] Kich hoat QR-MGS Core cho cot 183...", $time);
//        @(posedge clk);
//        start_core = 1;
//        @(posedge clk);
//        start_core = 0;

//        // Ch? tr?ng thái tính toán n?ng l??ng u
//        wait(uut.u_mgs_core.state == 4'd6); // Ch? ??n tr?ng thái CALC_U
//        #20; // ??i MAC tính xong
//        real_u = $itor(debug_u_val) / (2**26); // Vì MAC nhân Q13 * Q13 = Q26
//        $display("[%t] -> Energy u (Q26): %h (Real: %f)", $time, debug_u_val, real_u);

//        // Ch? tr?ng thái tính ISR (1/sqrt(u))
//        wait(uut.u_mgs_core.state == 4'd7); // Ch? ??n tr?ng thái CALC_ISR
//        #100; // ??i ISR done
//        real_rii = $itor(debug_rii_val) / (2**22); // ??nh d?ng Q2.22
//        $display("[%t] -> ISR Rii (Q22): %h (Real: %f)", $time, debug_rii_val, real_rii);

//        // ??i hoàn thành ghi vào Q BRAM
//        wait(core_done);
//        $display("[%t] QR-MGS Iteration 0 hoan tat!", $time);

//        // --- B??C 2: KI?M TRA TR?C GIAO HÓA (ITERATION 1) ---
//        // (Gi? s? Lambda ti?p theo là 167 nh? trong Log Matlab c?a b?n)
//        #200;
//        lambda_in = 8'd167; // 0xA7
//        current_i = 5'd1;
        
//        $display("\n[%t] Kich hoat QR-MGS Core cho cot 167 (Iteration 1)...", $time);
//        @(posedge clk);
//        start_core = 1;
//        @(posedge clk);
//        start_core = 0;

//        // Quan sát Alpha (Rji) - T??ng quan gi?a c?t 167 và c?t tr?c giao 183
//        wait(uut.u_mgs_core.state == 4'd3); // CALC_RJI
//        wait(uut.u_mgs_core.mac_done_latch);
//        real_alpha = $itor($signed(debug_alpha_val)) / 8192.0; // Q13
//        $display("[%t] -> Alpha R01 (Q13): %h (Real: %f)", $time, debug_alpha_val, real_alpha);

//        wait(core_done);
//        $display("[%t] QR-MGS Iteration 1 hoan tat!", $time);

//        $display("==========================================================");
//        #500;
//        $finish;
//    end

//endmodule


//`timescale 1ns / 1ps

//module tb_qr_mgs_system_test_top();

//    // --- Parameters ---
//    parameter DW = 24;
//    parameter ADDR_W_PHI = 12;
//    parameter ADDR_W_Q = 8;
//    parameter DOT_W = 56;
//    parameter PERIOD = 10; // 100 MHz

//    // --- Signals ---
//    reg clk;
//    reg rst_n;
//    reg start_core;
//    reg [7:0] lambda_in;
//    reg [4:0] current_i;
//    reg [3:0] M_rows;

//    wire core_done;
//    wire [DOT_W-1:0] debug_u_val;
//    wire [DW-1:0]    debug_alpha_val;
//    wire [DW-1:0]    debug_rii_val;
//    wire [95:0]      debug_qi_out;

//    // --- Instantiate DUT ---
//    qr_mgs_system_test_top #(
//        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W)
//    ) uut (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start_core(start_core),
//        .lambda_in(lambda_in),
//        .current_i(current_i),
//        .M_rows(M_rows),
//        .core_done(core_done),
//        .debug_u_val(debug_u_val),
//        .debug_alpha_val(debug_alpha_val),
//        .debug_rii_val(debug_rii_val),
//        .debug_qi_out(debug_qi_out)
//    );

//    // --- Clock Generation ---
//    initial clk = 0;
//    always #(PERIOD/2) clk = ~clk;

//    // --- Bi?n h? tr? quan sát s? th?c (Floating point) ---
//    real real_u, real_rii, real_alpha;

//    initial begin
//        // 1. Kh?i t?o
//        rst_n = 0;
//        start_core = 0;
//        lambda_in = 0;
//        current_i = 0;
//        M_rows = 4'hf; // 16 hàng (16x16)
        
//        #100;
//        rst_n = 1; // Nh? Reset
//        #50;

//        $display("==========================================================");
//        $display("   DEBUG QR-MGS SYSTEM: LAMBDA = 183 (0xB7)");
//        $display("==========================================================");

//        // --- TEST CASE: ITERATION 0 (Chu?n hóa c?t 183) ---
//        lambda_in = 8'd183;
//        current_i = 5'd0;
        
//        $display("[%t] GUI XUNG START_CORE...", $time);
//        @(posedge clk);
//        start_core = 1;
//        @(posedge clk);
//        start_core = 0;

//        // ??i ??n khi kh?i MAC tính xong n?ng l??ng u
//        // Tr?ng thái WAIT_U th??ng là state 7 trong FSM
//        wait(uut.u_mgs_core.state == 4'd7); 
//        #1; // ??i c?p nh?t dây n?i
//        real_u = $itor(debug_u_val) / (2.0**26); // DOT_W Q26.26
//        $display("[%t] -> Energy u (Q26): %h (Real: %f)", $time, debug_u_val, real_u);

//        // ??i ??n khi kh?i ISR tính xong 1/sqrt(u)
//        // Tr?ng thái WAIT_ISR th??ng là state 9 trong FSM
//        wait(uut.u_mgs_core.state == 4'd9);
//        #1;
//        real_rii = $itor(debug_rii_val) / (2.0**22); // ISR Q2.22
//        $display("[%t] -> ISR Rii (Q22): %h (Real: %f)", $time, debug_rii_val, real_rii);

//        // ??i tín hi?u hoàn thành
//        wait(core_done);
//        $display("[%t] CORE_DONE: Iteration 0 hoan tat!", $time);

//        // Ki?m tra k?t qu? ghi vào BRAM (??a ch? 0 c?a Q_BRAM)
//        #50;
//        $display("[%t] KET QUA KHOI PHUC Q0 (Dau ra bo nhan): %h", $time, debug_qi_out);
        
//        $display("==========================================================");
//        #500;
//        $finish;
//    end

//    // --- Monitor tr?ng thái ?? xem có b? treo không ---
//    always @(uut.u_mgs_core.state) begin
//        $display("   [FSM] Chuyen sang State: %d tai %t", uut.u_mgs_core.state, $time);
//    end

//endmodule

`timescale 1ns / 1ps

module tb_qr_mgs_system_test_top();

    // --- Parameters ---
    parameter DW = 24;
    parameter ADDR_W_PHI = 12;
    parameter ADDR_W_Q = 8;
    parameter DOT_W = 56;
    parameter PERIOD = 10; 

    // --- Signals ---
    reg clk, rst_n, start_core;
    reg [7:0] lambda_in;
    reg [4:0] current_i;
    reg [3:0] M_rows;

    wire core_done;
    wire [DOT_W-1:0] debug_u_val;
    wire [DW-1:0]    debug_alpha_val;
    wire [DW-1:0]    debug_rii_val;
    wire [95:0]      debug_qi_out;

    // --- Instantiate DUT ---
    qr_mgs_system_test_top #(
        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W)
    ) uut (
        .clk(clk), .rst_n(rst_n), .start_core(start_core),
        .lambda_in(lambda_in), .current_i(current_i), .M_rows(M_rows),
        .core_done(core_done),
        .debug_u_val(debug_u_val),
        .debug_alpha_val(debug_alpha_val),
        .debug_rii_val(debug_rii_val),
        .debug_qi_out(debug_qi_out)
    );

    // --- Clock Generation ---
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

    // --- Bi?n h? tr? quan sát ---
    real real_u, real_rii;

    initial begin
        // 1. Kh?i t?o
        rst_n = 0; start_core = 0; lambda_in = 8'd183; current_i = 5'd0; M_rows = 4'hf;
        
        #100; rst_n = 1; #50;

        $display("==========================================================");
        $display("   VERIFYING QR-MGS CORE: LAMBDA = 183 (0xB7)");
        $display("==========================================================");

        @(posedge clk); start_core = 1;
        @(posedge clk); start_core = 0;

        // --- B??C 1: ??i tính xong N?ng l??ng u ---
        // ??i cho ??n khi FSM thoát kh?i WAIT_U (7) ?? sang TRG_ISR (8)
        // ?ây là lúc mac_result_wire ?ã ?n ??nh và mac_done_latch = 1
        wait(uut.u_mgs_core.state == 4'd8); 
        #1; // ??m nh? 1ns
        real_u = $itor(uut.u_mgs_core.mac_res) / (2.0**26);
        $display("[%t] -> Energy u (Q26) Found: %h (Real: %f)", $time, uut.u_mgs_core.mac_res, real_u);

        // --- B??C 2: ??i tính xong ISR (Rii) ---
        // ??i cho ??n khi FSM thoát kh?i WAIT_ISR (9) ?? sang CALC_RII (10)
        // ?ây là lúc isr_val ?ã ???c ch?t vào r_ji_reg (debug_rii_val)
        wait(uut.u_mgs_core.state == 4'd10);
        #1;
        real_rii = $itor(debug_rii_val) / (2.0**22);
        $display("[%t] -> ISR Rii (Q22) Found  : %h (Real: %f)", $time, debug_rii_val, real_rii);

        // --- B??C 3: ??i toàn b? module hoàn thành ---
        wait(core_done);
        #100; 
        $display("[%t] CORE_DONE: Iteration 0 hoan tat!", $time);
        
        // L?y m?u vector ??u ra (ph?n t? ??u tiên)
        $display("   -> Final Qi Sample (Hex): %h", debug_qi_out);
        $display("==========================================================");
        
        #500;
        $finish;
    end

    // --- Monitor tr?ng thái FSM ---
    always @(uut.u_mgs_core.state) begin
        $display("   [FSM State Change] -> %d at %t", uut.u_mgs_core.state, $time);
    end

endmodule