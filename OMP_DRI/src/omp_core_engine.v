`timescale 1ns / 1ps

module omp_core_engine #
(
    // --- S?a: Tham s? h? th?ng ---
    parameter NUM_MAC    = 4,     // S? b? MAC song song
    parameter DW         = 24,    // ?? r?ng d? li?u (Q11.13)
    
    // --- S?a: Tham s? kích th??c ?nh 16x16 ---
    parameter COL_W      = 8,     // N=256 -> 8 bit
    parameter ROW_W      = 6,     // M_rows (M/4=16 -> c?n ít nh?t 5 bit, 6 bit an toàn)
    parameter K_W        = 5,     // K=16 -> 5 bit
    parameter ROW_N      = 4,     // Stride: log2(16) = 4
    
    // --- S?a: Tham s? ??a ch? RAM ---
    parameter ADDR_W_PHI = 12,    // Phi RAM: (N*M)/4 = 4096 dòng
    parameter ADDR_W_Q   = 12,    // Q RAM: (K*M)/4 = 256 dòng (16x16 dùng 8 bit, nòng lên 12 cho t??ng lai)
    parameter ADDR_W_R   = 12,    // R RAM: K*K = 256 dòng
    parameter ADDR_W_Y   = 6,     // Y RAM: M/4 = 16 dòng
    
    // --- S?a: Tham s? tính toán & Masking ---
    parameter DOT_W      = 56,
    parameter MAX_I      = 16,
    parameter HIST_BIT_V = 1,     // Bit Valid trong history
    parameter HIST_W     = COL_W + HIST_BIT_V // S?a: T? ??ng tính 8+1=9
)
(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start_omp,    
    
    // Tham s? c?u hình
    input  wire [COL_W-1:0]      N_cols,
    input  wire [ROW_W-1:0]      M_rows,
    input  wire [K_W-1:0]        K_sparsity,

    // Giao ti?p ghi Y ban ??u t? CPU/DMA
    input  wire                  y_we_cpu,
    input  wire [ADDR_W_Y-1:0]   y_addr_cpu,    // S?a: Dùng ADDR_W_Y
    input  wire [(NUM_MAC*DW)-1:0] y_din_cpu,   // S?a: Dùng NUM_MAC

    // B? sung: Giao ti?p ghi PHI ban ??u t? CPU/DMA
    input  wire                  phi_we_cpu,
    input  wire [ADDR_W_PHI-1:0] phi_addr_cpu,
    input  wire [(NUM_MAC*DW)-1:0] phi_din_cpu, // S?a: Dùng NUM_MAC

    // === GIAO TI?P V?I KH?I FINAL ESTIMATION (??C BRAM) ===
    input  wire                  est_running_flag, 
    
    input  wire [ADDR_W_Y-1:0]   est_y_addr_b,  // S?a: Dùng ADDR_W_Y
    output wire [(NUM_MAC*DW)-1:0] est_y_dout_b,

    input  wire [ADDR_W_Q-1:0]   est_q_addr_b,
    output wire [(NUM_MAC*DW)-1:0] est_q_dout_b,

    input  wire [ADDR_W_R-1:0]   est_r_addr_b,  // S?a: Dùng ADDR_W_R
    output wire [DW-1:0]         est_r_dout_b,

    // Tín hi?u Output
    output reg                   omp_done,
    output wire [MAX_I*COL_W-1:0] lambda_array_out
);

    // =========================================================================
    // 1. DÂY CÁP N?I B? (CHO KH?I OMP_CORE T? DÙNG)
    // =========================================================================
    wire [ADDR_W_Y-1:0] core_y_addr_b;
    wire [ADDR_W_Q-1:0] core_q_addr_b;

    // =========================================================================
    // 2. MUX CHIA S? BRAM (CORE vs FINAL_EST)
    // =========================================================================
    wire [ADDR_W_Y-1:0] final_y_addr_b = est_running_flag ? est_y_addr_b : core_y_addr_b;
    wire [ADDR_W_Q-1:0] final_q_addr_b = est_running_flag ? est_q_addr_b : core_q_addr_b;

    // =========================================================================
    // 3. INSTANTIATE BRAM IPs (S?a: S? d?ng NUM_MAC và Parameter ??a ch?)
    // =========================================================================
    
    wire [ADDR_W_PHI-1:0] phi_addr_b; 
    wire [(NUM_MAC*DW)-1:0] phi_dout_b;
    phi_bram u_phi_ram (
        .clka(clk),  .wea(phi_we_cpu), .addra(phi_addr_cpu), .dina(phi_din_cpu), 
        .clkb(clk),  .addrb(phi_addr_b), .doutb(phi_dout_b)
    );

    wire [(NUM_MAC*DW)-1:0] y_dout_b;
    y_bram u_y_ram (
        .clka(clk),  .wea(y_we_cpu), .addra(y_addr_cpu), .dina(y_din_cpu), 
        .clkb(clk),  .addrb(final_y_addr_b), .doutb(y_dout_b)              
    );
    assign est_y_dout_b = y_dout_b; 

    wire [ADDR_W_Y-1:0]  res_addr_a, res_addr_b; // S?a: ??ng b? v?i Y addr
    wire        res_we_a; 
    wire [(NUM_MAC*DW)-1:0] res_din_a, res_dout_b;
    res_vec_ram u_res_ram (
        .clka(clk),  .wea(res_we_a), .addra(res_addr_a), .dina(res_din_a),
        .clkb(clk),  .addrb(res_addr_b), .doutb(res_dout_b)
    );

    wire [ADDR_W_Q-1:0] q_addr_a; 
    wire                q_we_a; 
    wire [(NUM_MAC*DW)-1:0] q_din_a, q_dout_b;
    q_bram u_q_ram (
        .clka(clk),  .wea(q_we_a), .addra(q_addr_a), .dina(q_din_a), .douta(),
        .clkb(clk),  .web(1'b0), .addrb(final_q_addr_b), .dinb({(NUM_MAC*DW){1'b0}}), .doutb(q_dout_b) 
    );
    assign est_q_dout_b = q_dout_b; 

    wire [ADDR_W_R-1:0]  r_addr_a; 
    wire        r_we_a; 
    wire [DW-1:0] r_din_a, r_dout_b;
    r_bram u_r_ram (
        .clka(clk),  .wea(r_we_a), .addra(r_addr_a), .dina(r_din_a), .douta(),
        .clkb(clk),  .web(1'b0), .addrb(est_r_addr_b), .dinb({DW{1'b0}}), .doutb(r_dout_b) 
    );
    assign est_r_dout_b = r_dout_b;

    // =========================================================================
    // 4. FSM STATES & REGISTERS
    // =========================================================================
    localparam ST_IDLE         = 4'd0,
               ST_INIT_COPY    = 4'd1, 
               ST_START_ATOM   = 4'd2, 
               ST_WAIT_ATOM    = 4'd3, 
               ST_LATCH_LAMBDA = 4'd4, 
               ST_START_QR     = 4'd5, 
               ST_WAIT_QR      = 4'd6, 
               ST_CHECK_LOOP   = 4'd7, 
               ST_FINISH       = 4'd8; 

    reg [3:0]        state;
    reg [ROW_W-1:0]  init_cnt;   // S?a: Dùng ROW_W
    reg [K_W-1:0]    current_k;  // S?a: Dùng K_W

    reg  atom_start; wire atom_done; wire [COL_W-1:0] lambda_val;
    reg  qr_start;   wire qr_done;   reg  [COL_W-1:0] last_lambda;

    // L?ch s? Lambda
    reg [HIST_W-1:0] lambda_history [0:MAX_I-1];
    wire [MAX_I*HIST_W-1:0] lambda_history_flat;
    genvar g;
    generate
        for (g = 0; g < MAX_I; g = g + 1) begin : gen_history
            assign lambda_history_flat[g*HIST_W +: HIST_W] = lambda_history[g];
            assign lambda_array_out[g*COL_W +: COL_W]      = lambda_history[g][COL_W-1:0];
        end
    endgenerate

    // =========================================================================
    // 5. ??NG B? COPY Y -> RES_BRAM (S?a: Tham s? hóa Counter)
    // =========================================================================
    reg [ADDR_W_Y-1:0] y_addr_b_reg;
    assign core_y_addr_b = y_addr_b_reg;

    reg       res_we_init;
    reg [ADDR_W_Y-1:0] res_wa_init;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            res_we_init <= 1'b0; 
            res_wa_init <= 0;
        end else begin
            if (state == ST_INIT_COPY) begin
                if (init_cnt <= M_rows) begin
                    res_we_init <= 1'b1; 
                    res_wa_init <= init_cnt[ADDR_W_Y-1:0]; 
                end else begin
                    res_we_init <= 1'b0; 
                end
            end else begin
                res_we_init <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 6. B? PHÂN X? MUX N?I B? (S?a: Tham s? hóa ??a ch?)
    // =========================================================================
    wire [ADDR_W_PHI-1:0] atom_phi_addr, qr_phi_addr;
    wire [ADDR_W_Y-1:0]   atom_res_addr, qr_res_addr_b, qr_res_addr_a;
    wire                  qr_res_we_a;
    wire [(NUM_MAC*DW)-1:0] qr_res_din_a;

    wire is_atom_running = (state == ST_START_ATOM || state == ST_WAIT_ATOM);

    assign phi_addr_b = (is_atom_running) ? atom_phi_addr : qr_phi_addr;
    assign res_addr_b = (is_atom_running) ? atom_res_addr : qr_res_addr_b;

    assign res_we_a   = (state == ST_INIT_COPY) ? res_we_init : qr_res_we_a;
    assign res_addr_a = (state == ST_INIT_COPY) ? res_wa_init : qr_res_addr_a;
    assign res_din_a  = (state == ST_INIT_COPY) ? y_dout_b    : qr_res_din_a;

    // =========================================================================
    // 7. INSTANTIATE SUB-MODULES (S?a: Truy?n ??y ?? Parameter)
    // =========================================================================
    atom_selection_top #(
        .NUM_MAC(NUM_MAC), .DW(DW), .ADDR_W(ADDR_W_PHI), .ROW_W(ROW_W), 
        .COL_W(COL_W), .ROW_N(ROW_N), .DOT_W(DOT_W), .MAX_I(MAX_I)
    ) u_atom (
        .clk(clk), .rst_n(rst_n), .start(atom_start),
        .N_cols(N_cols), .M_rows(M_rows),
        .phi_addr(atom_phi_addr), .phi_data(phi_dout_b), 
        .r_addr(atom_res_addr),   .r_data(res_dout_b),
        .current_i({1'b0, current_k}), .lambda_history(lambda_history_flat),
        .lambda_out(lambda_val),  .atom_done(atom_done)
    );

    qr_mgs_core #(
        .NUM_MAC(NUM_MAC), .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ADDR_W_Q(ADDR_W_Q), 
        .ADDR_W_R(ADDR_W_R), .DOT_W(DOT_W), .COL_W(COL_W), .I_W(K_W), .M_W(ROW_W), .ROW_N(ROW_N)
    ) u_qr_mgs (
        .clk(clk), .rst_n(rst_n), .start_core(qr_start),
        .lambda_i(last_lambda), .current_i(current_k), .M_rows_in(M_rows),
        .phi_addr(qr_phi_addr), .phi_data(phi_dout_b),   
        .r_addr_a(r_addr_a),    .r_we_a(r_we_a),        .r_din_a(r_din_a),
        .q_addr_a(q_addr_a),    .q_we_a(q_we_a),        .q_din_a(q_din_a),
        .q_addr_b(core_q_addr_b),.q_dout_b(q_dout_b),
        .res_addr_a(qr_res_addr_a), .res_we_a(qr_res_we_a), .res_din_a(qr_res_din_a),
        .res_addr_b(qr_res_addr_b), .res_dout_b(res_dout_b),
        .core_done(qr_done)
    );

    // =========================================================================
    // 8. MASTER FSM (S?a: S? d?ng Parameter cho counter và Index)
    // =========================================================================
    integer im;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            init_cnt    <= 0; 
            current_k   <= 0;
            y_addr_b_reg <= {ADDR_W_Y{1'b1}}; // S?a: Reset v? c?c ??i ?? addr 0 là nh?p ??u
            omp_done    <= 0; atom_start <= 0; qr_start <= 0; last_lambda <= 0;
            for (im=0; im<MAX_I; im=im+1) lambda_history[im] <= 0;
        end else begin
            atom_start <= 1'b0; qr_start <= 1'b0; omp_done <= 1'b0;
            
            case (state)
                ST_IDLE: begin
                    if (start_omp) begin
                        state     <= ST_INIT_COPY; 
                        init_cnt  <= 0; 
                        y_addr_b_reg <= 0; 
                        current_k <= 0;
                        for (im=0; im<MAX_I; im=im+1) lambda_history[im] <= 0;
                    end
                end
                
                ST_INIT_COPY: begin 
                    if (init_cnt < M_rows) begin
                        y_addr_b_reg <= init_cnt[ADDR_W_Y-1:0] + 1'b1;
                    end
                    if (init_cnt >= M_rows + 2'd2) begin
                        state <= ST_START_ATOM;
                    end else begin
                        init_cnt <= init_cnt + 1'b1;
                    end
                end
                
                ST_START_ATOM: begin atom_start <= 1'b1; state <= ST_WAIT_ATOM; end
                ST_WAIT_ATOM:  if (atom_done) state <= ST_LATCH_LAMBDA;
                
                ST_LATCH_LAMBDA: begin
                    last_lambda <= lambda_val;
                    lambda_history[current_k] <= {1'b1, lambda_val};
                    state <= ST_START_QR;
                end
                
                ST_START_QR: begin qr_start <= 1'b1; state <= ST_WAIT_QR; end
                ST_WAIT_QR:  if (qr_done) state <= ST_CHECK_LOOP;
                
                ST_CHECK_LOOP: begin
                    if (current_k == K_sparsity - 1'b1) state <= ST_FINISH; 
                    else begin current_k <= current_k + 1'b1; state <= ST_START_ATOM; end
                end
                
                ST_FINISH: begin omp_done <= 1'b1; state <= ST_IDLE; end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule