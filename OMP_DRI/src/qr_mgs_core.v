`timescale 1ns / 1ps

module qr_mgs_core #
(
    // --- S?a: Tham s? h? th?ng ---
    parameter NUM_MAC    = 4,     // S? b? MAC song song
    parameter DW         = 24,    // ?? r?ng d? li?u (Q11.13)
    parameter DOT_W      = 56,    // ?? r?ng b? tích l?y
    
    // --- S?a: Tham s? kích th??c ?nh (M?c ??nh cho 16x16) ---
    parameter COL_W      = 8,     // N=256 -> 8 bit
    parameter I_W        = 4,     // K=16 -> 4 bit
    parameter M_W        = 6,     // M=64 -> 6 bit
    parameter ROW_N      = 4,     // Stride: log2(M/NUM_MAC) = log2(64/4) = 4
    
    // --- S?a: Tham s? ??a ch? RAM ---
    parameter ADDR_W_PHI = 12,    // 4096 deep
    parameter ADDR_W_Q   = 12,    // S?a: T?ng lên 12 ?? ?? cho ?nh l?n sau này
    parameter ADDR_W_R   = 12,    
    
    // --- S?a: Tham s? Q-format ---
    parameter FW_DATA    = 13,    // S? bit l? c?a d? li?u
    parameter FW_ISR     = 22     // S? bit l? ??u ra ISR
)
(
    input  wire                  clk, 
    input  wire                  rst_n, 
    input  wire                  start_core,      
    
    // Tham s? t? FSM T?ng
    input  wire [COL_W-1:0]      lambda_i,   // S?a: Dùng COL_W
    input  wire [I_W-1:0]        current_i,  // S?a: Dùng I_W
    input  wire [M_W-1:0]        M_rows_in,  // S?a: Dùng M_W

    // Giao ti?p Phi BRAM 
    output wire [ADDR_W_PHI-1:0] phi_addr,
    input  wire [(NUM_MAC*DW)-1:0] phi_data, // S?a: Dùng NUM_MAC

    // Giao ti?p R BRAM 
    output reg  [ADDR_W_R-1:0]   r_addr_a,   // S?a: Dùng ADDR_W_R
    output reg                   r_we_a,
    output reg  [DW-1:0]         r_din_a,

    // Giao ti?p Q BRAM 
    output wire [ADDR_W_Q-1:0]   q_addr_a,   // S?a: Dùng ADDR_W_Q
    output wire                  q_we_a,
    output wire [(NUM_MAC*DW)-1:0] q_din_a,
    output wire [ADDR_W_Q-1:0]   q_addr_b,
    input  wire [(NUM_MAC*DW)-1:0] q_dout_b,

    // Giao ti?p Residual RAM 
    output wire [M_W-1:0]        res_addr_a, // S?a: Dùng M_W
    output wire                  res_we_a,
    output wire [(NUM_MAC*DW)-1:0] res_din_a,
    output wire [M_W-1:0]        res_addr_b, 
    input  wire [(NUM_MAC*DW)-1:0] res_dout_b,

    output reg                   core_done
);

    // --- S?a: Tính toán ?? sâu b? nh? ??m W n?i b? ---
    localparam W_DEPTH = 1 << ROW_N; 

    // =========================================================================
    // 1. FSM STATES (Gi? nguyên)
    // =========================================================================
    localparam IDLE       = 4'd0, LOAD_W = 4'd1, J_INIT = 4'd2, TRG_MAC = 4'd3, 
               WAIT_MAC   = 4'd4, RJI_SUB = 4'd5, TRG_U = 4'd6, WAIT_U = 4'd7, 
               TRG_ISR    = 4'd8, WAIT_ISR = 4'd9, NORM_Q = 4'd10, TRG_ALPHA = 4'd11, 
               WAIT_ALPHA = 4'd12, UPD_RESID = 4'd13;

    reg [3:0] state;
    reg [I_W-1:0] j_cnt;      // S?a: Dùng I_W
    reg [M_W-1:0] r_ptr;      // S?a: Dùng M_W
    
    reg signed [DW-1:0] r_ji_reg, isr_reg, alpha_reg;
    reg mac_start, isr_start, mac_done_latch;

    // =========================================================================
    // 2. B? ??m W (S?a: Tham s? hóa ?? r?ng và ?? sâu)
    // =========================================================================
    wire        w_we_a; 
    wire [M_W-1:0]  w_addr_a; 
    wire [(NUM_MAC*DW)-1:0] w_din_a; 
    wire [M_W-1:0]  w_addr_b;
    wire [(NUM_MAC*DW)-1:0] w_dout_b;
    
    reg [(NUM_MAC*DW)-1:0] w_ram [0:W_DEPTH-1];
    reg [(NUM_MAC*DW)-1:0] w_dout_reg;
    
    always @(posedge clk) begin
        if(w_we_a) w_ram[w_addr_a] <= w_din_a;
        w_dout_reg <= w_ram[w_addr_b]; 
    end
    assign w_dout_b = w_dout_reg;

    // =========================================================================
    // 3. ??NH TUY?N ??A CH? (S?a: S? d?ng ROW_N ?? tính Stride)
    // =========================================================================
    wire [DOT_W-1:0] mac_res; 
    wire mac_done_p; 
    wire [M_W-1:0] mac_r_addr; 
    wire [ADDR_W_PHI-1:0] mac_phi_addr_p;

    wire is_mac_j = (state == TRG_MAC   || state == WAIT_MAC);
    wire is_mac_u = (state == TRG_U     || state == WAIT_U);
    wire is_mac_i = (state == TRG_ALPHA || state == WAIT_ALPHA);

    wire [(NUM_MAC*DW)-1:0] mac_in_phi = is_mac_u ? w_dout_b   : q_dout_b; 
    wire [(NUM_MAC*DW)-1:0] mac_in_r   = is_mac_i ? res_dout_b : w_dout_b; 

    // S?a: Thay phép nhân *16 b?ng d?ch bit << ROW_N
    assign phi_addr = (state == LOAD_W) ? (lambda_i << ROW_N) + r_ptr : mac_phi_addr_p;
    
    assign q_addr_b = is_mac_j ? ((j_cnt << ROW_N) + mac_phi_addr_p) : 
                      is_mac_i ? ((current_i << ROW_N) + mac_phi_addr_p) : 
                      (state == RJI_SUB) ? ((j_cnt << ROW_N) + r_ptr) :          
                      (state == UPD_RESID) ? ((current_i << ROW_N) + r_ptr) : {ADDR_W_Q{1'b0}};

    assign w_addr_b = (is_mac_j || is_mac_u) ? mac_r_addr :
                      (state == RJI_SUB || state == NORM_Q)  ? r_ptr : {M_W{1'b0}};

    assign res_addr_b = is_mac_i ? mac_r_addr :
                        (state == UPD_RESID)  ? r_ptr : {M_W{1'b0}};

    // =========================================================================
    // 4. DATAPATH: CÁC KH?I TOÁN H?C (S?a: Truy?n Parameter)
    // =========================================================================
    dot_product_4mac #(.NUM_MAC(NUM_MAC), .ROW_W(M_W), .ROW_N(ROW_N), .DW(DW), .ACC_W(DOT_W), .OUT_W(DOT_W)) u_mac (
        .clk(clk), .rst_n(rst_n), .start_a(mac_start), 
        .N_cols({COL_W{1'b0}}), .M_rows(M_rows_in),
        .phi_addr(mac_phi_addr_p), .phi_data(mac_in_phi), 
        .r_data(mac_in_r), .dot_result(mac_res), 
        .all_done(mac_done_p), .r_addr(mac_r_addr)
    );

    wire isr_done_p; wire [DW-1:0] isr_val;
    fast_isr #(.IN_W(DOT_W), .OUT_W(DW), .FW_IN(26), .FW_OUT(FW_ISR)) u_isr (
        .clk(clk), .rst_n(rst_n), .start(isr_start),
        .u_in(mac_res), .y_out(isr_val), .done(isr_done_p)
    );

    reg [DW-1:0] mul_scalar; reg [5:0] mul_shift; wire [(NUM_MAC*DW)-1:0] mul_res, sub_res;
    wire [(NUM_MAC*DW)-1:0] mul_vector_in = (state == NORM_Q) ? w_dout_b : q_dout_b; 
    reg [(NUM_MAC*DW)-1:0] vec_from_ram, vec_delay_1;
    
    mul_scalar_4set #(.DW(DW), .SW(DW), .NUM_SET(NUM_MAC)) u_mul (
        .clk(clk), .rst_n(rst_n), 
        .v_in(mul_vector_in), .scalar(mul_scalar), .shift(mul_shift), .v_out(mul_res)
    );

    sub_4set #(.DW(DW), .NUM_SET(NUM_MAC)) u_sub (
        .clk(clk), .rst_n(rst_n), 
        .a_vec(vec_delay_1), 
        .b_vec(mul_res), .res_vec(sub_res)
    );

    // =========================================================================
    // 5. THE GOLDEN PIPELINE (S?a: Tham s? hóa ?? r?ng ??a ch? Pipeline)
    // =========================================================================
    reg [M_W-1:0] addr_p1, addr_p2, addr_p3, addr_p4;
    reg we_load_p1, we_nrm_p1, we_nrm_p2, we_nrm_p3;
    reg we_sub_p1, we_sub_p2, we_sub_p3, we_sub_p4, is_rji_p1, is_rji_p2, is_rji_p3, is_rji_p4;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            addr_p1 <= 0; addr_p2 <= 0; addr_p3 <= 0; addr_p4 <= 0;
            we_load_p1 <= 0; we_nrm_p1 <= 0; we_nrm_p2 <= 0; we_nrm_p3 <= 0; 
            we_sub_p1 <= 0; we_sub_p2 <= 0; we_sub_p3 <= 0; we_sub_p4 <= 0; 
            is_rji_p1 <= 0; is_rji_p2 <= 0; is_rji_p3 <= 0; is_rji_p4 <= 0; 
            vec_from_ram <= 0; vec_delay_1 <= 0;
        end else begin
            addr_p1   <= r_ptr;
            we_load_p1<= (state == LOAD_W)    && (r_ptr <= M_rows_in);
            we_nrm_p1 <= (state == NORM_Q)    && (r_ptr <= M_rows_in);
            we_sub_p1 <= (state == RJI_SUB || state == UPD_RESID) && (r_ptr <= M_rows_in);
            is_rji_p1 <= (state == RJI_SUB);

            addr_p2   <= addr_p1; we_nrm_p2 <= we_nrm_p1; we_sub_p2 <= we_sub_p1; is_rji_p2 <= is_rji_p1;
            vec_from_ram <= (we_sub_p1) ? (is_rji_p1 ? w_dout_b : res_dout_b) : {(NUM_MAC*DW){1'b0}};

            addr_p3   <= addr_p2; we_nrm_p3 <= we_nrm_p2; we_sub_p3 <= we_sub_p2; is_rji_p3 <= is_rji_p2;
            vec_delay_1 <= vec_from_ram; 

            addr_p4   <= addr_p3; we_sub_p4 <= we_sub_p3; is_rji_p4 <= is_rji_p3;
        end
    end

    // GHI RAM (S?a: Tham s? hóa ??a ch? và Stride)
    assign w_we_a   = we_load_p1 | (we_sub_p4 & is_rji_p4);
    assign w_addr_a = we_load_p1 ? addr_p1 : addr_p4;
    assign w_din_a  = we_load_p1 ? phi_data : sub_res;

    assign q_we_a   = we_nrm_p3;
    assign q_addr_a = (current_i << ROW_N) + addr_p3; // S?a: Dùng d?ch bit
    assign q_din_a  = mul_res;

    assign res_we_a   = (we_sub_p4 & ~is_rji_p4);
    assign res_addr_a = addr_p4;
    assign res_din_a  = sub_res;

    // =========================================================================
    // 6. FSM ?I?U KHI?N (Gi? nguyên logic)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            state <= IDLE; core_done <= 0; mac_start <= 0; isr_start <= 0; mac_done_latch <= 0; 
            r_ptr <= 0; j_cnt <= 0; r_we_a <= 0; r_addr_a <= 0; r_din_a <= 0;
        end else begin
            core_done <= 0; mac_start <= 0; isr_start <= 0; r_we_a <= 0;
            if (mac_done_p) mac_done_latch <= 1;

            case(state)
                IDLE: begin r_ptr <= 0; if(start_core) state <= LOAD_W; end
                
                LOAD_W: begin
                    if(r_ptr >= M_rows_in + 1) begin state <= J_INIT; r_ptr <= 0; end 
                    else r_ptr <= r_ptr + 1'b1;
                end

                J_INIT: begin 
                    j_cnt <= 0; mac_done_latch <= 0; 
                    if(current_i == 0) state <= TRG_U; 
                    else state <= TRG_MAC; 
                end

                TRG_MAC: begin mac_start <= 1; state <= WAIT_MAC; end

                WAIT_MAC: begin
                    if(mac_done_latch) begin 
                        r_ji_reg <= mac_res[FW_DATA +: DW]; // S?a: Dùng FW_DATA
                        state <= RJI_SUB; r_ptr <= 0; mac_done_latch <= 0; 
                    end
                end

                RJI_SUB: begin
                    mul_scalar <= r_ji_reg; mul_shift <= FW_DATA; // S?a: Dùng FW_DATA
                    if (r_ptr == 0) begin
                        r_we_a   <= 1'b1; 
                        r_addr_a <= (j_cnt << ROW_N) + current_i; // S?a: Dùng ROW_N
                        r_din_a  <= r_ji_reg;
                    end
                    if(r_ptr >= M_rows_in + 4) begin 
                        r_ptr <= 0; 
                        if(j_cnt >= current_i - 1'b1) state <= TRG_U; 
                        else begin j_cnt <= j_cnt + 1'b1; state <= TRG_MAC; end
                    end else r_ptr <= r_ptr + 1'b1;
                end

                TRG_U: begin mac_start <= 1; state <= WAIT_U; end

                WAIT_U: begin
                    if(mac_done_latch) begin state <= TRG_ISR; mac_done_latch <= 0; end
                end

                TRG_ISR: begin isr_start <= 1; state <= WAIT_ISR; end

                WAIT_ISR: begin
                    if(isr_done_p) begin isr_reg <= isr_val; state <= NORM_Q; r_ptr <= 0; end
                end

                NORM_Q: begin
                    mul_scalar <= isr_reg; mul_shift <= FW_ISR; // S?a: Dùng FW_ISR
                    if (r_ptr == 0) begin
                        r_we_a   <= 1'b1; 
                        r_addr_a <= (current_i << ROW_N) + current_i; // S?a: Dùng ROW_N
                        r_din_a  <= isr_reg;
                    end
                    if(r_ptr >= M_rows_in + 3) begin state <= TRG_ALPHA; r_ptr <= 0; end 
                    else r_ptr <= r_ptr + 1'b1;
                end

                TRG_ALPHA: begin mac_start <= 1; state <= WAIT_ALPHA; end

                WAIT_ALPHA: begin
                    if(mac_done_latch) begin 
                        alpha_reg <= mac_res[FW_DATA +: DW]; // S?a: Dùng FW_DATA
                        state <= UPD_RESID; r_ptr <= 0; mac_done_latch <= 0; 
                    end
                end

                UPD_RESID: begin
                    mul_scalar <= alpha_reg; mul_shift <= FW_DATA; // S?a: Dùng FW_DATA
                    if(r_ptr >= M_rows_in + 4) begin core_done <= 1; state <= IDLE; end 
                    else r_ptr <= r_ptr + 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule


