`timescale 1ns / 1ps

module tb_residual_update_system_top();

    // --- 1. Tham s? h? th?ng ---
    parameter DW = 24;          // Q10.13
    parameter DOT_W = 56;
    parameter PERIOD = 10;      // 100MHz

    // --- 2. Tín hi?u k?t n?i ---
    reg clk;
    reg rst_n;
    reg start_update;
    reg [4:0] current_i;
    reg [3:0] M_rows;

    wire update_done;
    wire [23:0] debug_alpha_val;
    wire [95:0] debug_res_dout;

    // --- 3. Instantiate DUT (Module Top k?t n?i BRAM th?t) ---
    residual_update_system_top #(
        .DW(DW),
        .ADDR_W_Q(8),
        .DOT_W(DOT_W)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_update(start_update),
        .current_i(current_i),
        .M_rows(M_rows),
        .update_done(update_done),
        .debug_alpha_val(debug_alpha_val),
        .debug_res_dout(debug_res_dout)
    );

    // --- 4. T?o xung Clock ---
    initial clk = 0;
    always #(PERIOD/2) clk = ~clk;

    // --- 5. Bi?n h? tr? quan sát s? th?c ---
    real real_alpha;
    real r0, r1, r2, r3;
    integer k;

    // --- 6. Ti?n trình mô ph?ng ---
    initial begin
        // --- Kh?i t?o ---
        rst_n = 0;
        start_update = 0;
        current_i = 5'd0; // Gi? s? ki?m tra vi?c kh? th?ng d? b?ng c?t Q0
        M_rows = 4'd15;   // C?u hình 16x16 (64 m?u)
        
        #(PERIOD * 10);
        rst_n = 1;        // Nh? reset
        #(PERIOD * 5);

        $display("==========================================================");
        $display("   TESTING RESIDUAL UPDATE WITH REAL BRAM DATA (.coe)");
        $display("==========================================================");

        // --- B??c 1: Ki?m tra d? li?u y ban ??u t? BRAM ---
        // Port B c?a Residual RAM ?ang m?c ??nh tr? vào addr 0 lúc IDLE
        #10; 
        r0 = $itor($signed(debug_res_dout[23:0]))  / 8192.0;
        r1 = $itor($signed(debug_res_dout[47:24])) / 8192.0;
        $display("[%t] Initial Residual samples from BRAM y:", $time);
        $display("      y[0]=%f, y[1]=%f", r0, r1);
        if (r0 == 0.0) 
            $display("      [WARNING] D? li?u BRAM ?ang b?ng 0. Ki?m tra file .coe!");

        // --- B??c 2: Kích ho?t quy trình ---
        @(posedge clk);
        start_update = 1;
        @(posedge clk);
        start_update = 0;

        // --- B??c 3: ??i và l?y giá tr? Alpha (T??ng quan) ---
        // ??i cho ??n khi FSM c?a module con nh?y sang tr?ng thái 3 (UPDATE_LOOP)
        // ?ây là lúc Alpha ?ã ???c tính xong và ch?t vào thanh ghi
        wait(uut.u_residual_upd.state == 3'd3); 
        #1; // ??m nh? 1ns
        real_alpha = $itor($signed(debug_alpha_val)) / 8192.0;
        $display("[%t] >>> Alpha Calculated by HW: %f (Hex: %h)", $time, real_alpha, debug_alpha_val);

        // --- B??c 4: ??i hoàn thành c?p nh?t th?ng d? ---
        wait(update_done == 1'b1);
        $display("[%t] SUCCESS: Update Process Finished!", $time);
        #(PERIOD * 10);

        // --- B??c 5: ??c và in th?ng d? m?i r_new ?? ki?m tra h?i t? ---
        $display("\n--- FINAL RESIDUAL SAMPLES (Should be smaller than initial) ---");
        for (k = 0; k < 4; k = k + 1) begin
            // S? d?ng Peeking ?? ép ??a ch? ??c cho m?c ?ích ki?m tra
            force uut.u_residual_upd.res_addr_b = k[3:0]; 
            #10;
            r0 = $itor($signed(debug_res_dout[23:0]))  / 8192.0;
            r1 = $itor($signed(debug_res_dout[47:24])) / 8192.0;
            r2 = $itor($signed(debug_res_dout[71:48])) / 8192.0;
            r3 = $itor($signed(debug_res_dout[95:72])) / 8192.0;
            $display("Addr %0d: [%f, %f, %f, %f]", k, r0, r1, r2, r3);
            release uut.u_residual_upd.res_addr_b;
        end

        $display("==========================================================");
        #500;
        $finish;
    end

    // Monitor FSM ?? theo dõi ti?n ??
    always @(uut.u_residual_upd.state) begin
        $display("   [FSM Change] State -> %d at time %t", uut.u_residual_upd.state, $time);
    end

endmodule