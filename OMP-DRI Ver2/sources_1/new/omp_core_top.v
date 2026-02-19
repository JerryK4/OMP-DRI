//`timescale 1ns / 1ps

//module omp_core_top #
//(
//    parameter DW         = 24,    // Q10.13
//    parameter ADDR_W_PHI = 12,    // 4096 hàng Phi
//    parameter ADDR_W_Q   = 8,     // 256 hàng Q
//    parameter COL_W      = 8,     // 256 c?t
//    parameter MAX_K      = 16,    
//    parameter HIST_W     = 9      // {valid_bit, index[7:0]}
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start_omp,
    
//    // Tham s? c?u hình DRI
//    input  wire [COL_W-1:0] N_cols,     
//    input  wire [5:0]       M_rows,     // VD: 15 cho 16x16
//    input  wire [4:0]       K_limit,    
    
//    // Output quan sát
//    output reg [COL_W-1:0]  last_lambda,
//    output reg [4:0]        iteration_cnt,
//    output reg              omp_done
//);

//    // =====================================================
//    // 1. KHAI BÁO TR?NG THÁI FSM T?NG
//    // =====================================================
//    reg [3:0] state;
//    localparam IDLE         = 4'd0,
//               INIT_COPY    = 4'd1, // r = y (N?p th?ng d? ban ??u)
//               WAIT_INIT    = 4'd2, 
//               START_ATOM   = 4'd3, // Kh?i A: Tìm Lambda
//               WAIT_ATOM    = 4'd4, 
//               LATCH_LAMBDA = 4'd5, 
//               START_QR     = 4'd6, // Kh?i B1: Tr?c giao hóa
//               WAIT_QR      = 4'd7,
//               START_RESID  = 4'd8, // Kh?i B2: C?p nh?t th?ng d?
//               WAIT_RESID   = 4'd9,
//               LOOP_INC     = 4'd10,
//               FINISH       = 4'd11;

//    // =====================================================
//    // 2. TÍN HI?U ?I?U PH?I VÀ B? NH?
//    // =====================================================
//    reg [5:0] init_cnt, init_cnt_d1;
//    reg [4:0] current_k;
//    reg [HIST_W-1:0] lambda_history [0:MAX_K-1];
//    wire [MAX_K*HIST_W-1:0] packed_history;

//    // Pulse Triggers
//    reg start_a, start_b, start_c;
//    wire done_a, done_b, done_c;
//    wire [COL_W-1:0] lambda_val;

//    // Arbitration Wires (Muxing ??a ch? BRAM)
//    wire [11:0] phi_addr_final;    wire [95:0] phi_dout;
//    wire [3:0]  y_addr_final;      wire [95:0] y_dout;
//    wire [3:0]  res_addr_a_final,  res_addr_b_final;
//    wire        res_we_a_final;
//    wire [95:0] res_din_a_final,   res_dout_b_final;
//    wire [7:0]  q_addr_a_final,    q_addr_b_final;
//    wire        q_we_a_final;
//    wire [95:0] q_din_a_final,     q_dout_b_final;

//    // Tín hi?u t? các kh?i Slave
//    wire [11:0] phi_addr_b1, phi_addr_a;
//    wire [5:0]  res_addr_b_a; 
//    wire [3:0]  res_addr_a_b2, res_addr_b_b2;
//    wire [95:0] res_din_b2;    wire res_we_b2;
//    wire [7:0]  q_addr_a_b1, q_addr_b_b1, q_addr_b_b2;
//    wire [95:0] q_din_b1;      wire q_we_b1;

//    // -----------------------------------------------------
//    // Logic Phân Quy?n (Arbitration)
//    // -----------------------------------------------------
//    assign phi_addr_final = (state == START_QR || state == WAIT_QR) ? phi_addr_b1 : phi_addr_a;
//    assign y_addr_final   = init_cnt[3:0];

//    // Residual Port A (Ghi): INIT ho?c BLOCK B2
//    assign res_addr_a_final = (state == INIT_COPY) ? init_cnt_d1[3:0] : res_addr_a_b2;
//    assign res_we_a_final   = (state == INIT_COPY) ? (init_cnt_d1 <= M_rows && state != IDLE) : res_we_b2;
//    assign res_din_a_final  = (state == INIT_COPY) ? y_dout : res_din_b2;

//    // Residual Port B (??c): BLOCK A ho?c BLOCK B2
//    assign res_addr_b_final = (state == START_RESID || state == WAIT_RESID) ? res_addr_b_b2 : res_addr_b_a[3:0];

//    // Q Port B (??c): BLOCK B1 ho?c BLOCK B2
//    assign q_addr_b_final = (state == START_RESID || state == WAIT_RESID) ? q_addr_b_b2 : q_addr_b_b1;

//    // =====================================================
//    // 3. INSTANTIATE MODULES CON
//    // =====================================================

//    // Kh?i A: Atom Selection (Dùng Port B c?a Residual RAM)
//    atom_selection_top #(.DW(24), .ROW_W(6)) u_block_a (
//        .clk(clk), .rst_n(rst_n), .start(start_a),
//        .N_cols(N_cols), .M_rows(M_rows),
//        .phi_addr(phi_addr_a), .phi_data(phi_dout),
//        .r_addr(res_addr_b_a), .r_data(res_dout_b_final),
//        .current_i(current_k), .lambda_history(packed_history),
//        .lambda_out(lambda_val), .atom_done(done_a)
//    );

//    // Kh?i B1: QR-MGS Core (Ghi vào Q RAM và R RAM)
//    qr_mgs_core #(.DW(24)) u_block_b1 (
//        .clk(clk), .rst_n(rst_n), .start_core(start_b),
//        .lambda_i(lambda_val), .current_i(current_k), .M_rows_in(M_rows[3:0]),
//        .phi_addr(phi_addr_b1), .phi_data(phi_dout),
//        .q_addr_a(q_addr_a_b1), .q_we_a(q_we_b1), .q_din_a(q_din_b1),
//        .q_addr_b(q_addr_b_b1), .q_dout_b(q_dout_b_final),
//        .core_done(done_b)
//        // L?u ý: Port r_addr_a... có th? n?i ra R BRAM ? t?ng cao h?n
//    );

//    // Kh?i B2: Residual Update
//    residual_update #(.DW(24)) u_block_b2 (
//        .clk(clk), .rst_n(rst_n), .start_update(start_c),
//        .current_i(current_k), .M_rows(M_rows[3:0]),
//        .q_addr_b(q_addr_b_b2), .q_dout_b(q_dout_b_final),
//        .res_addr_a(res_addr_a_b2), .res_we_a(res_we_b2), .res_din_a(res_din_b2),
//        .res_addr_b(res_addr_b_b2), .res_dout_b(res_dout_b_final),
//        .update_done(done_c)
//    );

//    // =====================================================
//    // 4. MASTER FSM LOGIC
//    // =====================================================
//    integer ih;
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= IDLE; current_k <= 0; init_cnt <= 0; init_cnt_d1 <= 6'h3F;
//            start_a <= 0; start_b <= 0; start_c <= 0; omp_done <= 0;
//            for (ih=0; ih<MAX_K; ih=ih+1) lambda_history[ih] <= 0;
//        end else begin
//            init_cnt_d1 <= init_cnt; 
//            start_a <= 0; start_b <= 0; start_c <= 0; // Ép xung m?c ??nh

//            case (state)
//                IDLE: begin
//                    omp_done <= 0;
//                    if (start_omp) state <= INIT_COPY;
//                    init_cnt <= 0; current_k <= 0;
//                end

//                INIT_COPY: begin // r0 = y
//                    if (init_cnt == M_rows) state <= WAIT_INIT;
//                    else init_cnt <= init_cnt + 1'b1;
//                end

//                WAIT_INIT: state <= START_ATOM;

//                START_ATOM: begin start_a <= 1'b1; state <= WAIT_ATOM; end
//                WAIT_ATOM:  if (done_a) state <= LATCH_LAMBDA;

//                LATCH_LAMBDA: begin
//                    last_lambda <= lambda_val;
//                    lambda_history[current_k] <= {1'b1, lambda_val}; // Mark valid
//                    state <= START_QR;
//                end

//                START_QR: begin start_b <= 1'b1; state <= WAIT_QR; end
//                WAIT_QR:  if (done_b) state <= START_RESID;

//                START_RESID: begin start_c <= 1'b1; state <= WAIT_RESID; end
//                WAIT_RESID:  if (done_c) state <= LOOP_INC;

//                LOOP_INC: begin
//                    if (current_k == K_limit - 1'b1) state <= FINISH;
//                    else begin
//                        current_k <= current_k + 1'b1;
//                        state <= START_ATOM;
//                    end
//                end

//                FINISH: begin omp_done <= 1'b1; state <= IDLE; end
//                default: state <= IDLE;
//            endcase
//        end
//    end

//    // ?óng gói m?ng history sang wire cho Block A
//    genvar pk;
//    generate
//        for (pk = 0; pk < MAX_K; pk = pk + 1) begin : pack_h
//            assign packed_history[pk*HIST_W +: HIST_W] = lambda_history[pk];
//        end
//    endgenerate

//    always @(*) iteration_cnt = current_k;

//    // =====================================================
//    // 5. KH?I T?O CÁC IP BRAM (N?i vào Bus arbitration)
//    // =====================================================
//    phi_bram u_phi (.clka(clk), .addra(phi_addr_final), .douta(phi_dout));
//    y_bram   u_y   (.clka(clk), .addra(y_addr_final),   .douta(y_dout));
    
//    res_vec_ram u_res (
//        .clka(clk), .addra(res_addr_a_final), .wea(res_we_a_final), .dina(res_din_a_final), 
//        .clkb(clk), .addrb(res_addr_b_final), .doutb(res_dout_b_final)
//    );

//    q_bram u_q (
//        .clka(clk), .addra(q_addr_a_final), .wea(q_we_a_final), .dina(q_din_a_final), 
//        .clkb(clk), .addrb(q_addr_b_final), .doutb(q_dout_b_final)
//    );

//endmodule

`timescale 1ns / 1ps

module omp_core_top #
(
    parameter DW         = 24,    // Q10.13
    parameter ADDR_W_PHI = 12,    // 4096 hàng Phi
    parameter ADDR_W_Q   = 8,     // 256 hàng Q
    parameter COL_W      = 8,     // 256 c?t
    parameter MAX_K      = 16,    
    parameter HIST_W     = 9      // {valid_bit, index[7:0]}
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start_omp,
    
    // Tham s? c?u hình DRI
    input  wire [COL_W-1:0] N_cols,     
    input  wire [5:0]       M_rows,     // VD: 15 cho 16x16
    input  wire [4:0]       K_limit,    
    
    // Output quan sát
    output reg [COL_W-1:0]  last_lambda,
    output reg [4:0]        iteration_cnt,
    output reg              omp_done
);

    // =====================================================
    // 1. KHAI BÁO TR?NG THÁI FSM T?NG
    // =====================================================
    reg [3:0] state;
    localparam IDLE         = 4'd0,
               INIT_COPY    = 4'd1, // r = y (N?p th?ng d? ban ??u)
               WAIT_INIT    = 4'd2, 
               START_ATOM   = 4'd3, // Kh?i A: Tìm Lambda
               WAIT_ATOM    = 4'd4, 
               LATCH_LAMBDA = 4'd5, 
               START_QR     = 4'd6, // Kh?i B1: Tr?c giao hóa
               WAIT_QR      = 4'd7,
               START_RESID  = 4'd8, // Kh?i B2: C?p nh?t th?ng d?
               WAIT_RESID   = 4'd9,
               LOOP_INC     = 4'd10,
               FINISH       = 4'd11;

    // =====================================================
    // 2. TÍN HI?U ?I?U PH?I VÀ B? NH?
    // =====================================================
    reg [5:0] init_cnt, init_cnt_d1;
    reg [4:0] current_k;
    reg [HIST_W-1:0] lambda_history [0:MAX_K-1];
    wire [MAX_K*HIST_W-1:0] packed_history;

    // Pulse Triggers
    reg start_a, start_b, start_c;
    wire done_a, done_b, done_c;
    wire [COL_W-1:0] lambda_val;

    // Arbitration Wires (Muxing ??a ch? BRAM)
    wire [11:0] phi_addr_final;    wire [95:0] phi_dout;
    wire [3:0]  y_addr_final;      wire [95:0] y_dout;
    wire [3:0]  res_addr_a_final,  res_addr_b_final;
    wire        res_we_a_final;
    wire [95:0] res_din_a_final,   res_dout_b_final;
    wire [7:0]  q_addr_a_final,    q_addr_b_final;
    wire        q_we_a_final;
    wire [95:0] q_din_a_final,     q_dout_b_final;

    // Tín hi?u t? các kh?i Slave
    wire [11:0] phi_addr_b1, phi_addr_a;
    wire [5:0]  res_addr_b_a; 
    wire [3:0]  res_addr_a_b2, res_addr_b_b2;
    wire [95:0] res_din_b2;    wire res_we_b2;
    wire [7:0]  q_addr_a_b1, q_addr_b_b1, q_addr_b_b2;
    wire [95:0] q_din_b1;      wire q_we_b1;

    // -----------------------------------------------------
    // Logic Phân Quy?n (Arbitration)
    // -----------------------------------------------------
    assign phi_addr_final = (state == START_QR || state == WAIT_QR) ? phi_addr_b1 : phi_addr_a;
    assign y_addr_final   = init_cnt[3:0];

    // Residual Port A (Ghi): INIT ho?c BLOCK B2
    assign res_addr_a_final = (state == INIT_COPY) ? init_cnt_d1[3:0] : res_addr_a_b2;
    assign res_we_a_final   = (state == INIT_COPY) ? (init_cnt_d1 <= M_rows && state != IDLE) : res_we_b2;
    assign res_din_a_final  = (state == INIT_COPY) ? y_dout : res_din_b2;

    // Residual Port B (??c): BLOCK A ho?c BLOCK B2
    assign res_addr_b_final = (state == START_RESID || state == WAIT_RESID) ? res_addr_b_b2 : res_addr_b_a[3:0];

    // Q Port B (??c): BLOCK B1 ho?c BLOCK B2
    assign q_addr_b_final = (state == START_RESID || state == WAIT_RESID) ? q_addr_b_b2 : q_addr_b_b1;

    // =====================================================
    // 3. INSTANTIATE MODULES CON
    // =====================================================

    // Kh?i A: Atom Selection (Dùng Port B c?a Residual RAM)
    atom_selection_top #(.DW(24), .ROW_W(6)) u_block_a (
        .clk(clk), .rst_n(rst_n), .start(start_a),
        .N_cols(N_cols), .M_rows(M_rows),
        .phi_addr(phi_addr_a), .phi_data(phi_dout),
        .r_addr(res_addr_b_a), .r_data(res_dout_b_final),
        .current_i(current_k), .lambda_history(packed_history),
        .lambda_out(lambda_val), .atom_done(done_a)
    );

    // Kh?i B1: QR-MGS Core (Ghi vào Q RAM và R RAM)
    qr_mgs_core #(.DW(24)) u_block_b1 (
        .clk(clk), .rst_n(rst_n), .start_core(start_b),
        .lambda_i(lambda_val), .current_i(current_k), .M_rows_in(M_rows[3:0]),
        .phi_addr(phi_addr_b1), .phi_data(phi_dout),
        .q_addr_a(q_addr_a_b1), .q_we_a(q_we_b1), .q_din_a(q_din_b1),
        .q_addr_b(q_addr_b_b1), .q_dout_b(q_dout_b_final),
        .core_done(done_b)
        // L?u ý: Port r_addr_a... có th? n?i ra R BRAM ? t?ng cao h?n
    );

    // Kh?i B2: Residual Update
    residual_update #(.DW(24)) u_block_b2 (
        .clk(clk), .rst_n(rst_n), .start_update(start_c),
        .current_i(current_k), .M_rows(M_rows[3:0]),
        .q_addr_b(q_addr_b_b2), .q_dout_b(q_dout_b_final),
        .res_addr_a(res_addr_a_b2), .res_we_a(res_we_b2), .res_din_a(res_din_b2),
        .res_addr_b(res_addr_b_b2), .res_dout_b(res_dout_b_final),
        .update_done(done_c)
    );

    // =====================================================
    // 4. MASTER FSM LOGIC
    // =====================================================
    integer ih;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; current_k <= 0; init_cnt <= 0; init_cnt_d1 <= 6'h3F;
            start_a <= 0; start_b <= 0; start_c <= 0; omp_done <= 0;
            for (ih=0; ih<MAX_K; ih=ih+1) lambda_history[ih] <= 0;
        end else begin
            init_cnt_d1 <= init_cnt; 
            start_a <= 0; start_b <= 0; start_c <= 0; // Ép xung m?c ??nh

            case (state)
                IDLE: begin
                    omp_done <= 0;
                    if (start_omp) state <= INIT_COPY;
                    init_cnt <= 0; current_k <= 0;
                end

                INIT_COPY: begin // r0 = y
                    if (init_cnt == M_rows) state <= WAIT_INIT;
                    else init_cnt <= init_cnt + 1'b1;
                end

                WAIT_INIT: state <= START_ATOM;

                START_ATOM: begin start_a <= 1'b1; state <= WAIT_ATOM; end
                WAIT_ATOM:  if (done_a) state <= LATCH_LAMBDA;

                LATCH_LAMBDA: begin
                    last_lambda <= lambda_val;
                    lambda_history[current_k] <= {1'b1, lambda_val}; // Mark valid
                    state <= START_QR;
                end

                START_QR: begin start_b <= 1'b1; state <= WAIT_QR; end
                WAIT_QR:  if (done_b) state <= START_RESID;

                START_RESID: begin start_c <= 1'b1; state <= WAIT_RESID; end
                WAIT_RESID:  if (done_c) state <= LOOP_INC;

                LOOP_INC: begin
                    if (current_k == K_limit - 1'b1) state <= FINISH;
                    else begin
                        current_k <= current_k + 1'b1;
                        state <= START_ATOM;
                    end
                end

                FINISH: begin omp_done <= 1'b1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end

    // ?óng gói m?ng history sang wire cho Block A
    genvar pk;
    generate
        for (pk = 0; pk < MAX_K; pk = pk + 1) begin : pack_h
            assign packed_history[pk*HIST_W +: HIST_W] = lambda_history[pk];
        end
    endgenerate

    always @(*) iteration_cnt = current_k;

    // =====================================================
    // 5. KH?I T?O CÁC IP BRAM (N?i vào Bus arbitration)
    // =====================================================
    phi_bram u_phi (.clka(clk), .addra(phi_addr_final), .douta(phi_dout));
    
    y_bram u_y (
        .clka(clk),
        .wea(1'b0),        // Không ghi vào Y trong lúc ch?y OMP
        .addra(4'd0), 
        .dina(96'd0),
        
        .clkb(clk),        // C?p clock cho Port B
        .addrb(y_addr_final), // ??c ??a ch? y_mem_addr (t? Master FSM)
        .doutb(y_dout)  // D? li?u ra ? doutb (KHÔNG PH?I douta)
    );
    res_vec_ram u_res (
        .clka(clk), .addra(res_addr_a_final), .wea(res_we_a_final), .dina(res_din_a_final), 
        .clkb(clk), .addrb(res_addr_b_final), .doutb(res_dout_b_final)
    );

    q_bram u_q (
        .clka(clk), .addra(q_addr_a_final), .wea(q_we_a_final), .dina(q_din_a_final), 
        .clkb(clk), .addrb(q_addr_b_final), .doutb(q_dout_b_final)
    );

endmodule