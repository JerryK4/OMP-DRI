`timescale 1ns / 1ps

module qr_mgs_core #
(
    parameter DW         = 24,
    parameter ADDR_W_PHI = 12, // 4096 deep
    parameter ADDR_W_Q   = 8,  // 256 deep
    parameter DOT_W      = 56
)
(
    input  wire                  clk, 
    input  wire                  rst_n, 
    input  wire                  start_core,      
    
    // Tham s? t? FSM T?ng
    input  wire [7:0]            lambda_i,   
    input  wire [3:0]            current_i,  
    input  wire [5:0]            M_rows_in,  

    // Giao ti?p Phi BRAM 
    output wire [ADDR_W_PHI-1:0] phi_addr,
    input  wire [95:0]           phi_data,

    // Giao ti?p R BRAM 
    output reg  [7:0]            r_addr_a,
    output reg                   r_we_a,
    output reg  [23:0]           r_din_a,

    // Giao ti?p Q BRAM 
    output wire[ADDR_W_Q-1:0]   q_addr_a,
    output wire                  q_we_a,
    output wire [95:0]           q_din_a,
    output wire[ADDR_W_Q-1:0]   q_addr_b,
    input  wire [95:0]           q_dout_b,

    // Giao ti?p Residual RAM 
    output wire[3:0]            res_addr_a, 
    output wire                  res_we_a,
    output wire [95:0]           res_din_a,
    output wire [3:0]            res_addr_b, 
    input  wire [95:0]           res_dout_b,

    output reg                   core_done
);

    // =========================================================================
    // 1. FSM STATES
    // =========================================================================
    localparam IDLE       = 4'd0, 
               LOAD_W     = 4'd1, 
               J_INIT     = 4'd2, 
               TRG_MAC    = 4'd3, 
               WAIT_MAC   = 4'd4, 
               RJI_SUB    = 4'd5, 
               TRG_U      = 4'd6, 
               WAIT_U     = 4'd7, 
               TRG_ISR    = 4'd8, 
               WAIT_ISR   = 4'd9, 
               NORM_Q     = 4'd10, 
               TRG_ALPHA  = 4'd11, 
               WAIT_ALPHA = 4'd12, 
               UPD_RESID  = 4'd13;

    reg [3:0] state;
    reg [3:0] j_cnt;      
    reg [5:0] r_ptr;      
    
    reg signed[23:0] r_ji_reg, isr_reg, alpha_reg;
    reg mac_start, isr_start, mac_done_latch;

    // =========================================================================
    // 2. B? ??M W (Mô ph?ng chính xác ?? tr? 1 Clock c?a BRAM Xilinx)
    // =========================================================================
    wire        w_we_a; 
    wire[3:0]  w_addr_a; 
    wire [95:0] w_din_a; 
    wire [3:0]  w_addr_b;
    wire[95:0] w_dout_b;
    
    reg [95:0] w_ram [0:15];
    reg [95:0] w_dout_reg;
    
    always @(posedge clk) begin
        if(w_we_a) w_ram[w_addr_a] <= w_din_a;
        w_dout_reg <= w_ram[w_addr_b]; // Tr? 1 nh?p ??c
    end
    assign w_dout_b = w_dout_reg;

    // =========================================================================
    // 3. ??NH TUY?N ??A CH? T? H?P (THAY ??I QUAN TR?NG: C? is_mac_xx)
    // =========================================================================
    wire[DOT_W-1:0] mac_res; 
    wire mac_done_p; 
    wire [3:0] mac_r_addr; 
    wire[ADDR_W_PHI-1:0] mac_phi_addr_p;

    wire is_mac_j = (state == TRG_MAC   || state == WAIT_MAC);
    wire is_mac_u = (state == TRG_U     || state == WAIT_U);
    wire is_mac_i = (state == TRG_ALPHA || state == WAIT_ALPHA);

    // MUX d? li?u an toàn tuy?t ??i cho kh?i Tính n?ng l??ng (U)
    wire[95:0] mac_in_phi = is_mac_u ? w_dout_b   : q_dout_b; 
    wire [95:0] mac_in_r   = is_mac_i ? res_dout_b : w_dout_b; 

    assign phi_addr = (state == LOAD_W) ? (lambda_i * 16) + r_ptr : mac_phi_addr_p;
    
    assign q_addr_b = is_mac_j ? ((j_cnt * 16) + mac_phi_addr_p) : 
                      is_mac_i ? ((current_i * 16) + mac_phi_addr_p) : 
                      (state == RJI_SUB) ? ((j_cnt * 16) + r_ptr) :          
                      (state == UPD_RESID) ? ((current_i * 16) + r_ptr) : 8'h00;

    assign w_addr_b = (is_mac_j || is_mac_u) ? mac_r_addr :
                      (state == RJI_SUB || state == NORM_Q)  ? r_ptr : 4'h0;

    assign res_addr_b = is_mac_i ? mac_r_addr :
                        (state == UPD_RESID)  ? r_ptr : 4'h0;

    // =========================================================================
    // 4. DATAPATH: CÁC KH?I TOÁN H?C
    // =========================================================================
    dot_product_4mac #(.ROW_W(6)) u_mac (
        .clk(clk), .rst_n(rst_n), .start_a(mac_start), 
        .N_cols(8'd0), .M_rows(M_rows_in),
        .phi_addr(mac_phi_addr_p), .phi_data(mac_in_phi), 
        .r_data(mac_in_r), .dot_result(mac_res), 
        .all_done(mac_done_p), .r_addr(mac_r_addr)
    );

    wire isr_done_p; wire [23:0] isr_val;
    fast_isr u_isr (
        .clk(clk), .rst_n(rst_n), .start(isr_start),
        .u_in(mac_res), .y_out(isr_val), .done(isr_done_p)
    );

    reg[23:0] mul_scalar; reg [5:0] mul_shift; wire [95:0] mul_res, sub_res;
    wire [95:0] mul_vector_in = (state == NORM_Q) ? w_dout_b : q_dout_b; 
    reg [95:0] vec_from_ram, vec_delay_1;
    
    mul_scalar_4set u_mul (
        .clk(clk), .rst_n(rst_n), 
        .v_in(mul_vector_in), .scalar(mul_scalar), .shift(mul_shift), .v_out(mul_res)
    );

    // B? TR? l?y d? li?u t? `vec_delay_1` (Tr? chính xác 2 nh?p ?? g?p ???c mul_res)
    sub_4set u_sub (
        .clk(clk), .rst_n(rst_n), 
        .a_vec(vec_delay_1), 
        .b_vec(mul_res), .res_vec(sub_res)
    );

    // =========================================================================
    // 5. THE GOLDEN PIPELINE (B? ??NG B? 4 T?NG TUY?T ??I)
    // =========================================================================
    reg [3:0] addr_p1, addr_p2, addr_p3, addr_p4;
    
    reg we_load_p1;
    reg we_nrm_p1, we_nrm_p2, we_nrm_p3;
    reg we_sub_p1, we_sub_p2, we_sub_p3, we_sub_p4;
    reg is_rji_p1, is_rji_p2, is_rji_p3, is_rji_p4;

    

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            addr_p1 <= 0; addr_p2 <= 0; addr_p3 <= 0; addr_p4 <= 0;
            we_load_p1 <= 0;
            we_nrm_p1 <= 0; we_nrm_p2 <= 0; we_nrm_p3 <= 0; 
            we_sub_p1 <= 0; we_sub_p2 <= 0; we_sub_p3 <= 0; we_sub_p4 <= 0; 
            is_rji_p1 <= 0; is_rji_p2 <= 0; is_rji_p3 <= 0; is_rji_p4 <= 0; 
            vec_from_ram <= 0; vec_delay_1 <= 0;
        end else begin
            // ----- P1: Phát ??a ch? ??c (T) -----
            addr_p1   <= r_ptr[3:0];
            we_load_p1<= (state == LOAD_W)    && (r_ptr <= M_rows_in);
            we_nrm_p1 <= (state == NORM_Q)    && (r_ptr <= M_rows_in);
            we_sub_p1 <= (state == RJI_SUB || state == UPD_RESID) && (r_ptr <= M_rows_in);
            is_rji_p1 <= (state == RJI_SUB);

            // ----- P2: BRAM nh? Data (T+1) -----
            addr_p2   <= addr_p1; 
            we_nrm_p2 <= we_nrm_p1; 
            we_sub_p2 <= we_sub_p1; 
            is_rji_p2 <= is_rji_p1;
            
            // B?t ngay Vector G?c lòi ra t? BRAM
            vec_from_ram <= (we_sub_p1) ? (is_rji_p1 ? w_dout_b : res_dout_b) : 96'd0;

            // ----- P3: Kh?i Nhân tính xong (T+2) -> mul_res có m?t -----
            addr_p3   <= addr_p2;
            we_nrm_p3 <= we_nrm_p2; 
            we_sub_p3 <= we_sub_p2; 
            is_rji_p3 <= is_rji_p2;
            
            // Vector g?c tr? thêm 1 nh?p ?? ngang hàng v?i k?t qu? nhân
            vec_delay_1 <= vec_from_ram; 

            // ----- P4: Kh?i Tr? tính xong (T+3) -> sub_res có m?t -----
            addr_p4   <= addr_p3;
            we_sub_p4 <= we_sub_p3; 
            is_rji_p4 <= is_rji_p3;
        end
    end

    // ----- GHI VÀO RAM ? ?ÚNG NH?P PIPELINE -----
    
    // W_BRAM: Ghi Phi (Tr? 1 nh?p ? P1) HO?C Ghi k?t qu? Tr? MGS (Tr? 4 nh?p ? P4)
    assign w_we_a   = we_load_p1 | (we_sub_p4 & is_rji_p4);
    assign w_addr_a = we_load_p1 ? addr_p1 : addr_p4;
    assign w_din_a  = we_load_p1 ? phi_data : sub_res;

    // Q_BRAM: Ghi k?t qu? Nhân (Tr? 3 nh?p ? P3)
    assign q_we_a   = we_nrm_p3;
    assign q_addr_a = (current_i * 16) + addr_p3;
    assign q_din_a  = mul_res;

    // RES_BRAM: Ghi k?t qu? Tr? c?a Update Residual (Tr? 4 nh?p ? P4)
    assign res_we_a   = (we_sub_p4 & ~is_rji_p4);
    assign res_addr_a = addr_p4;
    assign res_din_a  = sub_res;

    // =========================================================================
    // 6. FSM ?I?U KHI?N
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            state <= IDLE; core_done <= 0; mac_start <= 0; isr_start <= 0; mac_done_latch <= 0; 
            r_ptr <= 0; j_cnt <= 0; r_we_a <= 0;
        end else begin
            core_done <= 0; mac_start <= 0; isr_start <= 0; r_we_a <= 0;
            if (mac_done_p) mac_done_latch <= 1;

            case(state)
                IDLE: begin 
                    r_ptr <= 0; 
                    if(start_core) state <= LOAD_W; 
                end
                
                LOAD_W: begin
                    if(r_ptr >= M_rows_in + 1) begin 
                        state <= J_INIT; r_ptr <= 0; 
                    end else r_ptr <= r_ptr + 1;
                end

                J_INIT: begin 
                    j_cnt <= 0; mac_done_latch <= 0; 
                    if(current_i == 0) state <= TRG_U; 
                    else state <= TRG_MAC; 
                end

                TRG_MAC: begin mac_start <= 1; state <= WAIT_MAC; end

                WAIT_MAC: begin
                    if(mac_done_latch) begin 
                        r_ji_reg <= mac_res[13 +: 24]; 
                        state <= RJI_SUB; r_ptr <= 0; mac_done_latch <= 0; 
                    end
                end

                RJI_SUB: begin
                    mul_scalar <= r_ji_reg; mul_shift <= 13;
                    
                    if (r_ptr == 0) begin
                        r_we_a   <= 1'b1; 
                        r_addr_a <= (j_cnt * 16) + current_i; 
                        r_din_a  <= r_ji_reg;
                    end

                    // Ch? P4 x? h?t b? tr? vào RAM
                    if(r_ptr >= M_rows_in + 4) begin 
                        r_ptr <= 0; 
                        if(j_cnt >= current_i - 1) state <= TRG_U; 
                        else begin j_cnt <= j_cnt + 1; state <= TRG_MAC; end
                    end else r_ptr <= r_ptr + 1;
                end

                TRG_U: begin mac_start <= 1; state <= WAIT_U; end

                WAIT_U: begin
                    if(mac_done_latch) begin state <= TRG_ISR; mac_done_latch <= 0; end
                end

                TRG_ISR: begin isr_start <= 1; state <= WAIT_ISR; end

                WAIT_ISR: begin
                    if(isr_done_p) begin 
                        isr_reg <= isr_val; 
                        state <= NORM_Q; r_ptr <= 0; 
                    end
                end

                NORM_Q: begin
                    mul_scalar <= isr_reg; mul_shift <= 22; 
                    
                    if (r_ptr == 0) begin
                        r_we_a   <= 1'b1; 
                        r_addr_a <= (current_i * 16) + current_i; 
                        r_din_a  <= isr_reg;
                    end

                    // Ch? P3 x? h?t b? nhân vào RAM
                    if(r_ptr >= M_rows_in + 3) begin 
                        state <= TRG_ALPHA; r_ptr <= 0; 
                    end else r_ptr <= r_ptr + 1;
                end

                TRG_ALPHA: begin mac_start <= 1; state <= WAIT_ALPHA; end

                WAIT_ALPHA: begin
                    if(mac_done_latch) begin 
                        alpha_reg <= mac_res[13 +: 24]; 
                        state <= UPD_RESID; r_ptr <= 0; mac_done_latch <= 0; 
                    end
                end

                UPD_RESID: begin
                    mul_scalar <= alpha_reg; mul_shift <= 13;
                    
                    // Ch? P4 x? h?t b? tr? vào RAM
                    if(r_ptr >= M_rows_in + 4) begin 
                        core_done <= 1; state <= IDLE; 
                    end else r_ptr <= r_ptr + 1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule