//`timescale 1ns / 1ps

//module residual_update #
//(
//    parameter DW = 24,         // Q10.13
//    parameter ADDR_W_Q = 8,    // 256 hàng t?ng cho ma tr?n Q
//    parameter DOT_W = 56
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start_update,
//    input  wire [4:0] current_i, // Ch? s? c?t Q v?a ???c t?o ra
//    input  wire [3:0] M_rows,    // DRI: 15 cho 16x16

//    // Giao ti?p Q BRAM (Port B)
//    output reg  [ADDR_W_Q-1:0] q_addr_b,
//    input  wire [95:0]         q_dout_b,

//    // Giao ti?p Residual RAM
//    output reg  [3:0]          res_addr_a, // Ghi
//    output reg                 res_we_a,
//    output reg  [95:0]         res_din_a,
//    output reg  [3:0]          res_addr_b, // ??c
//    input  wire [95:0]         res_dout_b,

//    output reg                 update_done
//);

//    // --- STATES ---
//    localparam IDLE        = 3'd0,
//               START_MAC   = 3'd1, // Phát xung kích ho?t MAC
//               WAIT_MAC    = 3'd2, // ??i Alpha = <Qi, r_old>
//               UPDATE_LOOP = 3'd3, // r_new = r_old - alpha * Qi
//               FINISH      = 3'd4;

//    reg [2:0] state;
//    reg [4:0] r_ptr; 
//    reg signed [23:0] alpha_reg;
//    reg start_mac_reg;
//    integer k;

//    // --- PIPELINE DELAY REGISTERS (Kh? X tuy?t ??i) ---
//    reg [3:0]  addr_pipe [0:5]; 
//    reg        we_pipe   [0:5];
//    reg [95:0] res_old_del [0:4];

//    always @(posedge clk) begin
//        // D?ch chuy?n ??a ch? và c? ghi ?? kh?p pha
//        addr_pipe[0] <= r_ptr[3:0];
//        we_pipe[0]   <= (state == UPDATE_LOOP && r_ptr <= M_rows);
        
//        for (k=1; k<6; k=k+1) begin
//            addr_pipe[k] <= addr_pipe[k-1];
//            we_pipe[k]   <= we_pipe[k-1];
//        end

//        // Trì hoãn r_old ?? ch? k?t qu? t? b? nhân Alpha*Qi (tr? 4 nh?p)
//        res_old_del[0] <= res_dout_b;
//        res_old_del[1] <= res_old_del[0];
//        res_old_del[2] <= res_old_del[1];
//        res_old_del[3] <= res_old_del[2];
//        res_old_del[4] <= res_old_del[3];
//    end

//    // --- 1. KH?I MAC TÍNH ALPHA ---
//    wire mac_done;
//    wire [DOT_W-1:0] mac_val;
//    wire [3:0] mac_res_addr_w;

//    dot_product_4mac #(.DW(24), .OUT_W(56), .ROW_W(4)) u_mac_resid (
//        .clk(clk), .rst_n(rst_n), .start_a(start_mac_reg),
//        .N_cols(8'd0), .M_rows(M_rows),
//        .phi_data(q_dout_b), .r_data(res_dout_b),
//        .dot_result(mac_val), .all_done(mac_done),
//        .row_cnt_out(mac_res_addr_w), .phi_addr(), .r_addr()
//    );

//    // --- 2. KH?I NHÂN SCALAR & B? TR? ---
//    wire [95:0] mul_out;
//    mul_scalar_4set #(.DW(24)) u_mul (
//        .clk(clk), .rst_n(rst_n), .v_in(q_dout_b), 
//        .scalar(alpha_reg), .shift(6'd13), .v_out(mul_out)
//    );

//    wire [95:0] sub_out;
//    sub_4set #(.DW(24)) u_sub (
//        .clk(clk), .rst_n(rst_n), 
//        .a_vec(res_old_del[3]), // Kh?p 4 nh?p tr?
//        .b_vec(mul_out), 
//        .res_vec(sub_out)
//    );

//    // --- 3. ?I?U KHI?N ??A CH? (Arbitration) ---
//    always @(*) begin
//        q_addr_b   = 8'hFF; // M?c ??nh an toàn
//        res_addr_b = 4'hF;
//        case (state)
//            WAIT_MAC: begin
//                q_addr_b   = (current_i << 4) + mac_res_addr_w;
//                res_addr_b = mac_res_addr_w;
//            end
//            UPDATE_LOOP: begin
//                q_addr_b   = (current_i << 4) + r_ptr[3:0];
//                res_addr_b = r_ptr[3:0];
//            end
//        endcase
//    end

//    // --- 4. MASTER FSM ---
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= IDLE; update_done <= 0; start_mac_reg <= 0;
//            res_we_a <= 0; res_addr_a <= 0; res_din_a <= 0;
//            r_ptr <= 0; alpha_reg <= 0;
//            // Kh?i t?o m?ng delay tránh l?i X
//            for (k=0; k<4; k=k+1) res_old_del[k] <= 0;
//        end else begin
//            res_we_a <= 0; // T?t ghi m?c ??nh
//            update_done <= 0;

//            case (state)
//                IDLE: begin
//                    if (start_update) begin
//                        state <= START_MAC;
//                        start_mac_reg <= 1'b1;
//                    end
//                end

//                START_MAC: begin
//                    start_mac_reg <= 1'b0; // T?o xung Pulse
//                    state <= WAIT_MAC;
//                end

//                WAIT_MAC: begin
//                    if (mac_done) begin
//                        alpha_reg <= mac_val[13 +: 24]; // Ch?t Alpha Q13
//                        state <= UPDATE_LOOP;
//                        r_ptr <= 0;
//                    end
//                end

//                UPDATE_LOOP: begin
//                    // Phát ??a ch? ??c (0 ??n M_rows)
//                    if (r_ptr <= M_rows) begin
//                        r_ptr <= r_ptr + 1'b1;
//                    end

//                    // Ghi th?ng d? m?i v?i ??a ch? ?ã delay ?úng 5 nh?p
//                    // 1(BRAM) + 2(Mul) + 1(Sub) + 1(Reg) = 5
//                    res_we_a   <= we_pipe[4]; 
//                    res_addr_a <= addr_pipe[4];
//                    res_din_a  <= sub_out;

//                    // Thoát khi ?ã ghi xong hàng cu?i cùng
//                    if (we_pipe[5] && addr_pipe[5] == M_rows) begin
//                        state <= FINISH;
//                    end
//                end

//                FINISH: begin
//                    update_done <= 1'b1;
//                    state <= IDLE;
//                end
//            endcase
//        end
//    end
//endmodule

////`timescale 1ns / 1ps
////module residual_update #
////(
////parameter DW = 24,         // Q10.13
////parameter ADDR_W_Q = 8,    // 256 hàng cho 16 c?t Q
////parameter DOT_W = 56       // B? tích l?y MAC
////)
////(
////input  wire clk,
////input  wire rst_n,
////input  wire start_update,
////input  wire [4:0] current_i, // C?t Qi v?a ???c t?o ra
////input  wire [3:0] M_rows,    // DRI: 15 cho 16x16
////// Giao ti?p Q BRAM (Ch? ??c)
////output reg  [ADDR_W_Q-1:0] q_addr_b,
////input  wire [95:0]         q_dout_b,

////// Giao ti?p Residual RAM (Port A: Ghi, Port B: ??c)
////output reg  [3:0]          res_addr_a, 
////output reg                 res_we_a,
////output reg  [95:0]         res_din_a,
////output reg  [3:0]          res_addr_b, 
////input  wire [95:0]         res_dout_b,

////output reg                 update_done
////);
////// --- Các tr?ng thái FSM ---
////localparam IDLE        = 3'd0,
////           START_MAC   = 3'd1, // Phát xung kh?i ??ng b? nhân tích vô h??ng
////           WAIT_MAC    = 3'd2, // ??i b? MAC tính xong Alpha
////           UPDATE_LOOP = 3'd3, // Vòng l?p n?p Pipeline và ghi k?t qu?
////           FINISH      = 3'd4;

////reg [2:0] state;
////reg [4:0] r_ptr; // Con tr? phát ??a ch? ??c (0..15)
////reg [4:0] w_ptr; // Con tr? phát l?nh ghi (0..15)
////reg signed [23:0] alpha_reg;

////// --- 1. Kh?i MAC (Tính alpha = <Qi, r_old>) ---
////reg start_mac_reg;
////wire mac_done;
////wire [DOT_W-1:0] mac_val;
////wire [3:0] mac_row;

////dot_product_4mac #(.DW(24), .OUT_W(56), .ROW_W(4)) u_mac_resid (
////    .clk(clk), .rst_n(rst_n), .start_a(start_mac_reg),
////    .N_cols(8'd0), .M_rows(4'd15),
////    .phi_data(q_dout_b), .r_data(res_dout_b),
////    .dot_result(mac_val), .all_done(mac_done),
////    .row_cnt_out(mac_row), .phi_addr(), .r_addr()
////);

////// --- 2. Cân b?ng Pipeline (Delay vector b? tr? ?? ??i b? nhân) ---
////// RAM tr? 1 nh?p, B? nhân tr? 2 nh?p -> T?ng tr? 3 nh?p.
////reg [95:0] res_delay [0:2];
////always @(posedge clk) begin
////    res_delay[0] <= res_dout_b;
////    res_delay[1] <= res_delay[0];
////    res_delay[2] <= res_delay[1];
////end

////// --- 3. B? nhân và B? tr? ---
////wire [95:0] mul_out;
////// Nhân alpha (Q13) v?i Qi (Q13) -> Q26. D?ch 13 bit ?? v? Q13.
////mul_scalar_4set #(.DW(24)) u_mul (.clk(clk), .rst_n(rst_n), .v_in(q_dout_b), .scalar(alpha_reg), .shift(6'd13), .v_out(mul_out));

////wire [95:0] sub_out;
////// Phép tr? chu?n nh?p: r_old (?ã tr? 3 nh?p) - (alpha * Qi)
////sub_4set #(.DW(24)) u_sub (.clk(clk), .rst_n(rst_n), .a_vec(res_delay[2]), .b_vec(mul_out), .res_vec(sub_out));

////// --- 4. Máy tr?ng thái chính (FSM) ---
////always @(posedge clk or negedge rst_n) begin
////    if (!rst_n) begin
////        state <= IDLE; update_done <= 0; start_mac_reg <= 0;
////        res_we_a <= 0; res_addr_a <= 0; res_din_a <= 0;
////        res_addr_b <= 0; q_addr_b <= 0;
////        r_ptr <= 0; w_ptr <= 0; alpha_reg <= 0;
////    end else begin
////        res_we_a <= 1'b0; // M?c ??nh t?t Write Enable ?? tránh l?i Latch/Z

////        case (state)
////            IDLE: begin
////                update_done <= 0;
////                if (start_update) begin
////                    state <= START_MAC;
////                    start_mac_reg <= 1'b1;
////                end
////            end

////            START_MAC: begin
////                start_mac_reg <= 1'b0; // T?t xung kích ho?t
////                state <= WAIT_MAC;
////            end

////            WAIT_MAC: begin
////                // ?i?u khi?n RAM cho b? MAC tính Alpha
////                q_addr_b   <= (current_i << 4) + mac_row;
////                res_addr_b <= mac_row;
////                if (mac_done) begin
////                    // Trích xu?t Q13 t? k?t qu? Q26 c?a MAC
////                    alpha_reg <= mac_val[13 +: 24]; 
////                    state <= UPDATE_LOOP;
////                    r_ptr <= 0; w_ptr <= 0;
////                end
////            end

////            UPDATE_LOOP: begin
////                // Phát ??a ch? ??C ch?y tr??c (0..15)
////                if (r_ptr < 16) begin
////                    q_addr_b   <= (current_i << 4) + r_ptr[3:0];
////                    res_addr_b <= r_ptr[3:0];
////                    r_ptr      <= r_ptr + 1'b1;
////                end

////                // L?nh GHI ?u?i theo sau 4 nh?p (??m b?o d? li?u nhân/tr? ?ã xong)
////                if (r_ptr >= 4) begin
////                    res_we_a   <= 1'b1;
////                    res_addr_a <= w_ptr[3:0];
////                    res_din_a  <= sub_out;
////                    w_ptr      <= w_ptr + 1'b1;
////                end

////                if (w_ptr == 16) begin
////                    state <= FINISH;
////                end
////            end

////            FINISH: begin
////                update_done <= 1'b1;
////                state <= IDLE;
////            end
            
////            default: state <= IDLE;
////        endcase
////    end
////end
////endmodule


//`timescale 1ns / 1ps

//module residual_update #
//(
//    parameter DW = 24,         // Q10.13
//    parameter ADDR_W_Q = 8,    // 256 hàng t?ng cho ma tr?n Q (16 c?t * 16 hàng)
//    parameter DOT_W = 56
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start_update,
//    input  wire [4:0] current_i, // Ch? s? c?t Q v?a ???c t?o ra (0-15)
//    input  wire [3:0] M_rows,    // DRI: 15 cho 16x16 (t??ng ?ng 16 hàng)

//    // Giao ti?p Q BRAM (Port B)
//    output reg  [ADDR_W_Q-1:0] q_addr_b,
//    input  wire [95:0]         q_dout_b,

//    // Giao ti?p Residual RAM
//    output reg  [3:0]          res_addr_a, // C?ng Ghi r_new
//    output reg                 res_we_a,
//    output reg  [95:0]         res_din_a,
//    output reg  [3:0]          res_addr_b, // C?ng ??c r_old
//    input  wire [95:0]         res_dout_b,

//    output reg                 update_done
//);

//    // --- STATES ---
//    localparam IDLE        = 3'd0,
//               START_MAC   = 3'd1, // Kích ho?t tính Alpha
//               WAIT_MAC    = 3'd2, // Ch? k?t qu? tích vô h??ng
//               UPDATE_PIPE = 3'd3, // Quá trình ??y d? li?u qua Pipeline
//               FINISH      = 3'd4;

//    reg [2:0] state;
//    reg [4:0] r_ptr; 
//    reg signed [23:0] alpha_reg;
//    reg start_mac_reg;
//    integer k;

//    // --- PIPELINE DELAY REGISTERS ---
//    // C?n kh?p nh?p: RAM_Read(1) + Mul(2) + Sub(1) = 4 nh?p
//    reg [3:0]  addr_pipe [0:5]; 
//    reg        we_pipe   [0:5];
//    reg [95:0] res_old_del [0:4];

//    always @(posedge clk) begin
//        // Delay line cho ??a ch? và tín hi?u ghi
//        addr_pipe[0] <= r_ptr[3:0];
//        we_pipe[0]   <= (state == UPDATE_PIPE && r_ptr <= M_rows);
        
//        for (k=1; k<6; k=k+1) begin
//            addr_pipe[k] <= addr_pipe[k-1];
//            we_pipe[k]   <= we_pipe[k-1];
//        end

//        // Delay r_old ?? ch? k?t qu? t? b? nhân (Mul scalar có latency = 2)
//        // Nh?p 0: Phát ??a ch?
//        // Nh?p 1: r_old t? RAM v? bus -> res_old_del[0]
//        // Nh?p 2: r_old_del[1]
//        // Nh?p 3: r_old_del[2] (Kh?p v?i ??u ra b? nhân mul_out)
//        res_old_del[0] <= res_dout_b;
//        for (k=1; k<5; k=k+1) res_old_del[k] <= res_old_del[k-1];
//    end

//    // --- 1. KH?I MAC TÍNH ALPHA ---
//    wire mac_done;
//    wire [DOT_W-1:0] mac_val;
//    wire [3:0] mac_phi_addr_w; // ??a ch? do MAC t? phát
//    wire [3:0] mac_res_addr_w;

//    dot_product_4mac #(.DW(24), .OUT_W(56), .ROW_W(4)) u_mac_resid (
//        .clk(clk), .rst_n(rst_n), .start_a(start_mac_reg),
//        .N_cols(8'd0), .M_rows(M_rows),
//        .phi_data(q_dout_b), .r_data(res_dout_b),
//        .dot_result(mac_val), .all_done(mac_done),
//        .phi_addr(mac_phi_addr_w), .r_addr(mac_res_addr_w)
//    );

//    // --- 2. KH?I NHÂN SCALAR & B? TR? ---
//    wire [95:0] mul_out;
//    mul_scalar_4set #(.DW(24)) u_mul (
//        .clk(clk), .rst_n(rst_n), .v_in(q_dout_b), 
//        .scalar(alpha_reg), .shift(6'd13), .v_out(mul_out)
//    );

//    wire [95:0] sub_out;
//    sub_4set #(.DW(24)) u_sub (
//        .clk(clk), .rst_n(rst_n), 
//        .a_vec(res_old_del[2]), // r_old ?ã ch? ?? 3 nh?p t? khi ra kh?i RAM
//        .b_vec(mul_out), 
//        .res_vec(sub_out)
//    );

//    // --- 3. ?I?U KHI?N ??A CH? (Arbitration) ---
//    always @(*) begin
//        // Ghép ??a ch? Q: (S? th? t? c?t * 16 hàng) + Hàng hi?n t?i
//        case (state)
//            WAIT_MAC: begin
//                q_addr_b   = (current_i << 4) + mac_phi_addr_w;
//                res_addr_b = mac_res_addr_w;
//            end
//            UPDATE_PIPE: begin
//                q_addr_b   = (current_i << 4) + r_ptr[3:0];
//                res_addr_b = r_ptr[3:0];
//            end
//            default: begin
//                q_addr_b   = 8'h00;
//                res_addr_b = 4'h0;
//            end
//        endcase
//    end

//    // --- 4. MASTER FSM ---
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= IDLE; update_done <= 0; start_mac_reg <= 0;
//            res_we_a <= 0; res_addr_a <= 0; res_din_a <= 0;
//            r_ptr <= 0; alpha_reg <= 0;
//        end else begin
//            res_we_a <= 0; 
//            update_done <= 0;

//            case (state)
//                IDLE: begin
//                    if (start_update) begin
//                        state <= START_MAC;
//                        start_mac_reg <= 1'b1;
//                    end
//                end

//                START_MAC: begin
//                    start_mac_reg <= 1'b0; 
//                    state <= WAIT_MAC;
//                end

//                WAIT_MAC: begin
//                    if (mac_done) begin
//                        // --- S?A L?I ALPHA = 0 (Check Overflow & Saturation) ---
//                        if (|mac_val[55:37] && !mac_val[55]) // D??ng quá l?n
//                            alpha_reg <= 24'h7FFFFF;
//                        else if (!(&mac_val[55:37]) && mac_val[55]) // Âm quá l?n
//                            alpha_reg <= 24'h800000;
//                        else
//                            alpha_reg <= mac_val[13 +: 24]; // L?y chu?n Q10.13

//                        state <= UPDATE_PIPE;
//                        r_ptr <= 0;
//                    end
//                end

//                UPDATE_PIPE: begin
//                    // Phát ??a ch? ??c
//                    if (r_ptr <= M_rows) begin
//                        r_ptr <= r_ptr + 1'b1;
//                    end

//                    // Ghi k?t qu? sau khi ?i h?t Pipeline
//                    // Latency = 4 nh?p tính toán + 1 nh?p ch?t ??a ch? = addr_pipe[4]
//                    res_we_a   <= we_pipe[4]; 
//                    res_addr_a <= addr_pipe[4];
//                    res_din_a  <= sub_out;

//                    // Thoát khi hàng cu?i cùng (M_rows) ?ã ???c ghi xong
//                    if (we_pipe[4] && addr_pipe[4] == M_rows) begin
//                        state <= FINISH;
//                    end
//                end

//                FINISH: begin
//                    update_done <= 1'b1;
//                    state <= IDLE;
//                end
//            endcase
//        end
//    end
//endmodule

`timescale 1ns / 1ps

module residual_update #
(
    parameter DW = 24,         // Q10.13
    parameter ADDR_W_Q = 8,    // 256 rows
    parameter DOT_W = 56
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start_update,
    input  wire [4:0] current_i, 
    input  wire [3:0] M_rows,    // 15 cho 16x16

    // Interface Q BRAM
    output reg  [7:0]            q_addr_b,
    input  wire [95:0]         q_dout_b,

    // Interface Residual RAM
    output reg  [3:0]            res_addr_a, 
    output reg                 res_we_a,
    output reg  [95:0]         res_din_a,
    output reg  [3:0]          res_addr_b, 
    input  wire [95:0]         res_dout_b,

    output reg                 update_done
);

    // --- STATES ---
    localparam IDLE=0, TRG_ALPHA=1, WAIT_ALPHA=2, UPDATE_PIPE=3, FINISH=4;
    reg [2:0] state;
    reg [5:0] row_cnt; 
    reg signed [23:0] alpha_reg;
    reg mac_start, mac_done_latch;

    // --- PIPELINE DELAY REGISTERS (Kh? hoàn toàn l?i X) ---
    reg [3:0]  addr_del [0:5];
    reg        we_del   [0:5];
    reg [95:0] res_old_del [0:4];
    integer k;

    // --- 1. KH?I MAC TÍNH ALPHA (<Qi, r_old>) ---
    wire mac_done_p; wire [DOT_W-1:0] mac_val; wire [3:0] mac_addr_bus;
    dot_product_4mac #(.DW(24), .OUT_W(56), .ROW_W(4)) u_mac_resid (
        .clk(clk), .rst_n(rst_n), .start_a(mac_start), .M_rows(M_rows), .N_cols(8'd0),
        .phi_data(q_dout_b), .r_data(res_dout_b),
        .dot_result(mac_val), .all_done(mac_done_p), .row_cnt_out(mac_addr_bus)
    );

    // --- 2. KH?I NHÂN SCALAR & B? TR? ---
    wire [95:0] mul_out, sub_out;
    // (Q13 * Q13) >> 13 -> K?t qu? Q13
    mul_scalar_4set #(.DW(24)) u_mul (.clk(clk), .rst_n(rst_n), .v_in(q_dout_b), .scalar(alpha_reg), .shift(6'd13), .v_out(mul_out));
    // Phép tr? chu?n nh?p: r_old (delay 3 nh?p) - (Alpha * Qi)
    sub_4set #(.DW(24)) u_sub (.clk(clk), .rst_n(rst_n), .a_vec(res_old_del[3]), .b_vec(mul_out), .res_vec(sub_out));

    // --- 3. ?I?U PH?I ??A CH? (ARBITRATION) ---
    always @(*) begin
        q_addr_b   = (current_i << 4); // M?i ??a ch? hàng 0
        res_addr_b = 4'h0;
        case (state)
            WAIT_ALPHA: begin q_addr_b = (current_i << 4) + mac_addr_bus; res_addr_b = mac_addr_bus; end
            UPDATE_PIPE: begin q_addr_b = (current_i << 4) + row_cnt[3:0]; res_addr_b = row_cnt[3:0]; end
            default: begin q_addr_b = 8'hFF; res_addr_b = 4'hF; end // Tránh Collision Simulation
        endcase
    end

    // --- 4. MASTER FSM & PIPELINE SYNC ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; update_done <= 0; mac_start <= 0; mac_done_latch <= 0;
            res_we_a <= 0; res_addr_a <= 0; res_din_a <= 0; row_cnt <= 0;
            for (k=0; k<6; k=k+1) begin addr_del[k] <= 0; we_del[k] <= 0; end
            for (k=0; k<5; k=k+1) res_old_del[k] <= 0;
        end else begin
            res_we_a <= 0; update_done <= 0;
            if (mac_done_p) mac_done_latch <= 1'b1;

            // Pipeline shifting logic
            addr_del[0] <= row_cnt[3:0];
            we_del[0]   <= (state == UPDATE_PIPE && row_cnt <= M_rows);
            for (k=1; k<6; k=k+1) begin addr_del[k] <= addr_del[k-1]; we_del[k] <= we_del[k-1]; end
            
            res_old_del[0] <= res_dout_b;
            for (k=1; k<5; k=k+1) res_old_del[k] <= res_old_del[k-1];

            case (state)
                IDLE: begin
                    row_cnt <= 0; mac_done_latch <= 0;
                    if (start_update) begin state <= TRG_ALPHA; mac_start <= 1; end
                end

                TRG_ALPHA: begin
                    mac_start <= 0; // T?o xung Pulse 1 chu k?
                    state <= WAIT_ALPHA;
                end

                WAIT_ALPHA: begin
                    if (mac_done_latch) begin
                        alpha_reg <= mac_val[13 +: 24]; // Ch?t Alpha Q13
                        state <= UPDATE_PIPE;
                        row_cnt <= 0;
                    end
                end

                UPDATE_PIPE: begin
                    if (row_cnt <= M_rows) row_cnt <= row_cnt + 1'b1;
                    else row_cnt <= row_cnt + 1'b1; // ??m ti?p ?? x? pipeline

                    // Ghi vào RAM v?i ??a ch? ?ã delay chu?n 5 nh?p
                    res_we_a   <= we_del[4];
                    res_addr_a <= addr_del[4];
                    res_din_a  <= sub_out;

                    // Thoát an toàn sau 22 nh?p (??m b?o hàng cu?i ?ã ghi xong)
                    if (row_cnt >= 6'd22) state <= FINISH;
                end

                FINISH: begin
                    update_done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule


