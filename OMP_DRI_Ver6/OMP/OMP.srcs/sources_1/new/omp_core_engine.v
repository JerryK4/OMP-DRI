`timescale 1ns / 1ps

module omp_core_engine #
(
    parameter DW         = 24,
    parameter ADDR_W_PHI = 12,
    parameter ROW_W      = 6,
    parameter COL_W      = 8,
    parameter ADDR_W_Q   = 8,
    parameter DOT_W      = 56,
    parameter MAX_I      = 16,
    parameter HIST_W     = 9
)
(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start_omp,    
    
    // Tham s? c?u hình
    input  wire [COL_W-1:0]      N_cols,
    input  wire [ROW_W-1:0]      M_rows,
    input  wire [4:0]            K_sparsity,

    // Giao ti?p ghi y ban ??u t? CPU/DMA
    input  wire                  y_we_cpu,
    input  wire [3:0]            y_addr_cpu,
    input  wire[95:0]           y_din_cpu,

    // === GIAO TI?P V?I KH?I FINAL ESTIMATION (??C BRAM) ===
    input  wire                  est_running_flag, // C? MUX: 1 = Final Est ?ang ch?y
    
    input  wire [3:0]            est_y_addr_b,
    output wire [95:0]           est_y_dout_b,

    input  wire [ADDR_W_Q-1:0]   est_q_addr_b,
    output wire [95:0]           est_q_dout_b,

    input  wire [7:0]            est_r_addr_b,
    output wire [23:0]           est_r_dout_b,

    // Tín hi?u Output
    output reg                   omp_done,
    output wire [MAX_I*COL_W-1:0] lambda_array_out
);

    // =========================================================================
    // 1. DÂY CÁP N?I B? (CHO KH?I OMP_CORE T? DÙNG)
    // =========================================================================
    wire[3:0]  core_y_addr_b;
    wire[ADDR_W_Q-1:0] core_q_addr_b;

    // =========================================================================
    // 2. MUX CHIA S? BRAM (CORE vs FINAL_EST)
    // Khi est_running_flag = 1, BRAM s? l?ng nghe ??a ch? t? kh?i Final Est
    // =========================================================================
    wire[3:0]  final_y_addr_b = est_running_flag ? est_y_addr_b : core_y_addr_b;
    wire [ADDR_W_Q-1:0] final_q_addr_b = est_running_flag ? est_q_addr_b : core_q_addr_b;

    // =========================================================================
    // 3. INSTANTIATE XILINX BRAM IPs 
    // =========================================================================
    wire [ADDR_W_PHI-1:0] phi_addr; 
    wire [95:0]           phi_dout;
    phi_bram u_phi_ram (
        .clka(clk),  .wea(1'b0), .addra(phi_addr), .dina(96'd0), .douta(phi_dout)
    );

    wire [95:0] y_dout_b;
    y_bram u_y_ram (
        .clka(clk),  .wea(y_we_cpu), .addra(y_addr_cpu), .dina(y_din_cpu), // Port A CPU
        .clkb(clk),  .addrb(final_y_addr_b), .doutb(y_dout_b)              // Port B MUX
    );
    assign est_y_dout_b = y_dout_b; // Xu?t ng??c ra cho Est

    wire [3:0]  res_addr_a, res_addr_b; 
    wire        res_we_a; 
    wire [95:0] res_din_a, res_dout_b;
    res_vec_ram u_res_ram (
        .clka(clk),  .wea(res_we_a), .addra(res_addr_a), .dina(res_din_a),
        .clkb(clk),  .addrb(res_addr_b), .doutb(res_dout_b)
    );

    wire[ADDR_W_Q-1:0] q_addr_a; 
    wire                q_we_a; 
    wire [95:0]         q_din_a, q_dout_b;
    q_bram u_q_ram (
        .clka(clk),  .wea(q_we_a), .addra(q_addr_a), .dina(q_din_a), .douta(),
        .clkb(clk),  .web(1'b0), .addrb(final_q_addr_b), .dinb(96'd0), .doutb(q_dout_b) // Port B MUX
    );
    assign est_q_dout_b = q_dout_b; // Xu?t ng??c ra cho Est

    wire[7:0]  r_addr_a; 
    wire        r_we_a; 
    wire [23:0] r_din_a, r_dout_b;
    r_bram u_r_ram (
        .clka(clk),  .wea(r_we_a), .addra(r_addr_a), .dina(r_din_a), .douta(),
        // Port B chuyên ph?c v? Final Est (ch?y Back-sub)
        .clkb(clk),  .web(1'b0), .addrb(est_r_addr_b), .dinb(24'd0), .doutb(r_dout_b) 
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

    reg [3:0] state;
    reg [5:0] init_cnt;   
    reg [4:0] current_k;  

    reg  atom_start; wire atom_done; wire [COL_W-1:0] lambda_val;
    reg  qr_start;   wire qr_done;   reg[COL_W-1:0] last_lambda;

    // L?ch s? Lambda
    reg [HIST_W-1:0] lambda_history [0:MAX_I-1];
    wire[MAX_I*HIST_W-1:0] lambda_history_flat;
    genvar g;
    generate
        for (g = 0; g < MAX_I; g = g + 1) begin : gen_history
            assign lambda_history_flat[g*HIST_W +: HIST_W] = lambda_history[g];
            assign lambda_array_out[g*COL_W +: COL_W]      = lambda_history[g][COL_W-1:0];
        end
    endgenerate

    // =========================================================================
    // 5. ??NG B? COPY Y -> RES_BRAM
    // =========================================================================
    assign core_y_addr_b = init_cnt[3:0];

    reg       res_we_init;
    reg [3:0] res_wa_init;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            res_we_init <= 1'b0; res_wa_init <= 4'd0;
        end else begin
            if (state == ST_INIT_COPY) begin
                if (init_cnt <= M_rows) begin
                    res_we_init <= 1'b1; res_wa_init <= init_cnt[3:0]; 
                end else begin
                    res_we_init <= 1'b0; 
                end
            end else begin
                res_we_init <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 6. B? PHÂN X? MUX (ADDRESS ARBITRATION)
    // =========================================================================
    wire [ADDR_W_PHI-1:0] atom_phi_addr, qr_phi_addr;
    wire [3:0]            atom_res_addr, qr_res_addr_b, qr_res_addr_a;
    wire                  qr_res_we_a;
    wire[95:0]           qr_res_din_a;

    wire is_atom_running = (state == ST_START_ATOM || state == ST_WAIT_ATOM);

    assign phi_addr   = (is_atom_running) ? atom_phi_addr : qr_phi_addr;
    assign res_addr_b = (is_atom_running) ? atom_res_addr : qr_res_addr_b;

    assign res_we_a   = (state == ST_INIT_COPY) ? res_we_init : qr_res_we_a;
    assign res_addr_a = (state == ST_INIT_COPY) ? res_wa_init : qr_res_addr_a;
    assign res_din_a  = (state == ST_INIT_COPY) ? y_dout_b    : qr_res_din_a;

    // =========================================================================
    // 7. INSTANTIATE SUB-MODULES TOÁN H?C
    // =========================================================================
    atom_selection_top u_atom (
        .clk(clk), .rst_n(rst_n), .start(atom_start),
        .N_cols(N_cols), .M_rows(M_rows),
        .phi_addr(atom_phi_addr), .phi_data(phi_dout),
        .r_addr(atom_res_addr), .r_data(res_dout_b),
        .current_i(current_k), .lambda_history(lambda_history_flat),
        .lambda_out(lambda_val), .atom_done(atom_done)
    );

    qr_mgs_core u_qr_mgs (
        .clk(clk), .rst_n(rst_n), .start_core(qr_start),
        .lambda_i(last_lambda), .current_i(current_k[3:0]), .M_rows_in(M_rows),
        .phi_addr(qr_phi_addr), .phi_data(phi_dout),
        .r_addr_a(r_addr_a), .r_we_a(r_we_a), .r_din_a(r_din_a),
        .q_addr_a(q_addr_a), .q_we_a(q_we_a), .q_din_a(q_din_a),
        .q_addr_b(core_q_addr_b), .q_dout_b(q_dout_b),
        .res_addr_a(qr_res_addr_a), .res_we_a(qr_res_we_a), .res_din_a(qr_res_din_a),
        .res_addr_b(qr_res_addr_b), .res_dout_b(res_dout_b),
        .core_done(qr_done)
    );

    // =========================================================================
    // 8. MASTER FSM
    // =========================================================================
    integer im;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            init_cnt    <= 0; current_k <= 0;
            omp_done    <= 0; atom_start <= 0; qr_start <= 0; last_lambda <= 0;
            for (im=0; im<MAX_I; im=im+1) lambda_history[im] <= 0;
        end else begin
            atom_start <= 1'b0; qr_start <= 1'b0; omp_done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (start_omp) begin
                        state <= ST_INIT_COPY; init_cnt <= 0; current_k <= 0;
                        for (im=0; im<MAX_I; im=im+1) lambda_history[im] <= 0;
                    end
                end
                ST_INIT_COPY: begin 
                    if (init_cnt <= M_rows + 1) init_cnt <= init_cnt + 1'b1;
                    else state <= ST_START_ATOM;
                end
                ST_START_ATOM: begin atom_start <= 1'b1; state <= ST_WAIT_ATOM; end
                ST_WAIT_ATOM:  if (atom_done) state <= ST_LATCH_LAMBDA;
                ST_LATCH_LAMBDA: begin
                    last_lambda <= lambda_val;
                    lambda_history[current_k[3:0]] <= {1'b1, lambda_val};
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