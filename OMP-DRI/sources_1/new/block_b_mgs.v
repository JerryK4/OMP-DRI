`timescale 1ns / 1ps

module block_b_mgs (
    input wire clk,
    input wire rst_n,
    input wire start_b,
    input wire [5:0] lambda,      
    input wire [4:0] current_i,   
    input wire [2:0] M_limit,     // M?c ??nh là 7 (?ng v?i 8 dòng BRAM 96-bit)
    
    // Giao ti?p BRAM Phi
    output reg [8:0]  phi_addr,
    input wire [95:0] phi_data,

    // Giao ti?p BRAM Q
    output reg [6:0]  q_addr,
    output reg [95:0] q_wdata,
    output reg        q_we,
    input wire [95:0] q_rdata,
    
    // Giao ti?p BRAM R
    output reg [2:0]  r_addr,
    output reg [95:0] r_wdata,
    output reg        r_we,
    input wire [95:0] r_rdata,

    // Giao ti?p BRAM U
    output reg [5:0]  u_addr,   
    output reg [95:0] u_wdata,
    output reg        u_we,
    
    output reg done_b
);

    // --- 1. B? ??m n?i b? và Bi?n ?i?u khi?n ---
    reg signed [95:0] w_buffer [0:7];
    reg signed [23:0] u_col_buffer [0:15]; // Ch?a 16 ph?n t? c?a c?t U hi?n t?i
    reg [95:0] q_collect;
    
    reg [3:0]  state;
    reg [2:0]  row_cnt;
    reg [2:0]  row_cnt_d1; // Delay ??a ch? 1 nh?p ?? kh?p d? li?u BRAM tr? v?
    reg [4:0]  j_cnt;
    reg [5:0]  div_cnt_sent, div_cnt_recv;
    reg [3:0]  wait_cnt;

    localparam S_IDLE        = 4'd0,
               S_LOAD_PHI    = 4'd1,
               S_CHECK_J     = 4'd2,
               S_DOT_UJI_REQ = 4'd3,
               S_DOT_UJI_ACC = 4'd4,
               S_SUB_REQ     = 4'd5,
               S_SUB_EXEC    = 4'd6,
               S_CALC_UII    = 4'd7,
               S_DIVIDE_QI   = 4'd8,
               S_UP_R_LATCH  = 4'd9, 
               S_UPDATE_R_DOT= 4'd10, 
               S_UPDATE_R_SUB= 4'd11,
               S_WRITE_U     = 4'd12,
               S_DONE        = 4'd13;

    // --- 2. Logic tính toán ---
    reg  signed [63:0] uji_acc;
    wire signed [23:0] uji_final = uji_acc[36:13]; // Trích xu?t Q10.13 t? tích Q26
    wire signed [47:0] dot_out_4;
    wire [95:0] vec_updated; 

    reg  signed [63:0] uii_acc;
    wire signed [23:0] uii_final = uii_acc[36:13];

    // Module MAC (Tích vô h??ng 4 lu?ng song song)
    wire [95:0] mac_in_a = (state == S_CALC_UII) ? w_buffer[row_cnt_d1] : q_rdata;
    wire [95:0] mac_in_b = (state == S_UPDATE_R_DOT) ? r_rdata : w_buffer[row_cnt_d1];

    mac_4_parallel inst_mac (
        .a0(mac_in_a[23:0]),  .a1(mac_in_a[47:24]), .a2(mac_in_a[71:48]), .a3(mac_in_a[95:72]),
        .b0(mac_in_b[23:0]),  .b1(mac_in_b[47:24]), .b2(mac_in_b[71:48]), .b3(mac_in_b[95:72]),
        .sum_out(dot_out_4)
    );

    // Module Sub-Scale (Th?c hi?n vector - scalar * vector)
    vec_sub_scale_unit inst_sub (
        .scalar_u(uji_final), 
        .vec_q(q_rdata),
        .vec_w_old((state == S_UPDATE_R_SUB) ? r_rdata : w_buffer[row_cnt_d1]),
        .vec_w_new(vec_updated)
    );

    // --- 3. IP Divider (Yêu c?u c?u hình SIGNED 40/24) ---
    reg signed [39:0] div_dividend;
    reg               div_start;
    wire [63:0]       div_dout;
    wire              div_valid;

    div_gen_0 inst_divider (
        .aclk(clk), .aresetn(rst_n),
        .s_axis_dividend_tdata(div_dividend), .s_axis_dividend_tvalid(div_start),
        .s_axis_divisor_tdata(uii_final),     .s_axis_divisor_tvalid(div_start),
        .m_axis_dout_tdata(div_dout),         .m_axis_dout_tvalid(div_valid)
    );

    // --- 4. FSM Logic ---
    integer k_u;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; done_b <= 0; q_we <= 0; r_we <= 0; u_we <= 0;
            div_start <= 0; uji_acc <= 0; uii_acc <= 0;
            row_cnt <= 0; row_cnt_d1 <= 0; j_cnt <= 0;
            for (k_u=0; k_u<16; k_u=k_u+1) u_col_buffer[k_u] <= 0;
        end else begin
            row_cnt_d1 <= row_cnt; // Pipeline ??a ch?

            case (state)
                S_IDLE: begin
                    done_b <= 0; q_we <= 0; r_we <= 0; u_we <= 0;
                    if (start_b) begin
                        state <= S_LOAD_PHI; phi_addr <= (lambda << 3); row_cnt <= 0;
                        for (k_u=0; k_u<16; k_u=k_u+1) u_col_buffer[k_u] <= 0;
                    end
                end

                S_LOAD_PHI: begin // N?p c?t Phi t? BRAM ngoài vào buffer n?i
                    if (row_cnt_d1 <= M_limit) w_buffer[row_cnt_d1] <= phi_data;
                    if (row_cnt_d1 == M_limit) begin
                        state <= S_CHECK_J; j_cnt <= 0; row_cnt <= 0;
                    end else begin
                        row_cnt <= row_cnt + 1;
                        phi_addr <= (lambda << 3) + (row_cnt + 1);
                    end
                end

                S_CHECK_J: begin
                    if (j_cnt < current_i) begin
                        state <= S_DOT_UJI_REQ; row_cnt <= 0; uji_acc <= 0;
                    end else begin
                        state <= S_CALC_UII; row_cnt <= 0; uii_acc <= 0;
                    end
                end

                S_DOT_UJI_REQ: begin // Tính uji = <w, Qj>
                    q_addr <= (j_cnt << 3) + row_cnt;
                    state  <= S_DOT_UJI_ACC;
                end

                S_DOT_UJI_ACC: begin
                    if (row_cnt_d1 <= M_limit && (row_cnt > 0 || state == S_DOT_UJI_ACC)) 
                        uji_acc <= uji_acc + $signed(dot_out_4);
                    
                    if (row_cnt_d1 == M_limit) begin
                        u_col_buffer[j_cnt] <= uji_final;
                        state <= S_SUB_REQ; row_cnt <= 0;
                    end else begin
                        row_cnt <= row_cnt + 1;
                        q_addr <= (j_cnt << 3) + (row_cnt + 1);
                    end
                end

                S_SUB_REQ: begin // C?p nh?t w = w - uji*Qj
                    q_addr <= (j_cnt << 3) + row_cnt;
                    state  <= S_SUB_EXEC;
                end

                S_SUB_EXEC: begin
                    if (row_cnt_d1 <= M_limit) w_buffer[row_cnt_d1] <= vec_updated;
                    if (row_cnt_d1 == M_limit) begin
                        j_cnt <= j_cnt + 1; state <= S_CHECK_J; row_cnt <= 0;
                    end else begin
                        row_cnt <= row_cnt + 1;
                        q_addr <= (j_cnt << 3) + (row_cnt + 1);
                    end
                end

//                S_CALC_UII: begin // Tính uii = ||w||
//                    if (row_cnt_d1 <= M_limit && (row_cnt > 0 || state == S_CALC_UII)) 
//                        uii_acc <= uii_acc + $signed(dot_out_4);
                    
//                    if (row_cnt_d1 == M_limit) begin
//                        u_col_buffer[current_i] <= uii_final;
//                        state <= S_DIVIDE_QI; div_cnt_sent <= 0; div_cnt_recv <= 0;
//                    end else row_cnt <= row_cnt + 1;
//                end

//                S_DIVIDE_QI: begin // Q_i = w / uii
//                    if (div_cnt_sent < ((M_limit + 1) << 2)) begin
//                        div_start <= 1'b1;
//                        // Sign extension và scaling Q26
//                        div_dividend <= $signed(w_buffer[div_cnt_sent[5:2]][div_cnt_sent[1:0]*24 +: 24]) << 13;
//                        div_cnt_sent <= div_cnt_sent + 1;
//                    end else div_start <= 1'b0;

//                    q_we <= 1'b0;
//                    if (div_valid) begin
//                        // L?y Quotient [47:24]
//                        case (div_cnt_recv[1:0])
//                            2'b00: q_collect[23:0]  <= div_dout[47:24];
//                            2'b01: q_collect[47:24] <= div_dout[47:24];
//                            2'b10: q_collect[71:48] <= div_dout[47:24];
//                            2'b11: begin
//                                q_we <= 1'b1;
//                                q_addr <= (current_i << 3) + (div_cnt_recv >> 2);
//                                q_wdata <= {div_dout[47:24], q_collect[71:0]};
//                            end
//                        endcase
//                        div_cnt_recv <= div_cnt_recv + 1;
//                        if (div_cnt_recv == ((M_limit + 1) << 2) - 1) begin
//                            state <= S_UP_R_LATCH; row_cnt <= 0; uji_acc <= 0;
//                            q_addr <= (current_i << 3); r_addr <= 0;
//                        end
//                    end
//                end
                S_CALC_UII: begin // TÍNH uii = ||w||^2
                    // Gi? nguyên ?i?u ki?n pipeline nh? c?
                    if (row_cnt_d1 <= M_limit && (row_cnt > 0 || state == S_CALC_UII)) 
                        uii_acc <= uii_acc + $signed(dot_out_4);  // dot_out_4 = w·w (Q26)
                
                    if (row_cnt_d1 == M_limit) begin
                        // uii_acc là Q26 ? l?y Q13 c?a ||w||^2
                        u_col_buffer[current_i] <= uii_acc[36:13];
                        state <= S_DIVIDE_QI;
                        div_cnt_sent <= 0;
                        div_cnt_recv <= 0;
                    end else begin
                        row_cnt <= row_cnt + 1;
                    end
                end
                S_DIVIDE_QI: begin // Q_i = w / uii
                    if (div_cnt_sent < ((M_limit + 1) << 2)) begin
                        div_start <= 1'b1;
                        // Gi? nguyên scaling Q26
                        div_dividend <= 
                            $signed(w_buffer[div_cnt_sent[5:2]][div_cnt_sent[1:0]*24 +: 24]) <<< 13;
                        div_cnt_sent <= div_cnt_sent + 1;
                    end else begin
                        div_start <= 1'b0;
                    end
                
                    q_we <= 1'b0;
                    if (div_valid) begin
                        // ? L?Y ?ÚNG QUOTIENT Q13
                        case (div_cnt_recv[1:0])
                            2'b00: q_collect[23:0]  <= div_dout[23:0];
                            2'b01: q_collect[47:24] <= div_dout[23:0];
                            2'b10: q_collect[71:48] <= div_dout[23:0];
                            2'b11: begin
                                q_we <= 1'b1;
                                q_addr <= (current_i << 3) + (div_cnt_recv >> 2);
                                q_wdata <= {div_dout[23:0], q_collect[71:0]};
                            end
                        endcase
                
                        div_cnt_recv <= div_cnt_recv + 1;
                        if (div_cnt_recv == ((M_limit + 1) << 2) - 1) begin
                            state <= S_UP_R_LATCH;
                            row_cnt <= 0;
                            uji_acc <= 0;
                            q_addr <= (current_i << 3);
                            r_addr <= 0;
                        end
                    end
                end



                S_UP_R_LATCH: begin // Ch? BRAM Q ph?n h?i nh?p ??u
                    state <= S_UPDATE_R_DOT;
                end

                S_UPDATE_R_DOT: begin // alpha = <R, Qi>
                    if (row_cnt_d1 <= M_limit && (row_cnt > 0 || state == S_UPDATE_R_DOT)) 
                        uji_acc <= uji_acc + $signed(dot_out_4);
                    
                    if (row_cnt_d1 == M_limit) begin
                        row_cnt <= 0; state <= S_UPDATE_R_SUB;
                        q_addr <= (current_i << 3); r_addr <= 0;
                    end else begin
                        row_cnt <= row_cnt + 1;
                        q_addr <= (current_i << 3) + row_cnt;
                        r_addr <= row_cnt;
                    end
                end

                S_UPDATE_R_SUB: begin // R = R - alpha*Qi
                    if (row_cnt_d1 <= M_limit) begin
                        r_we <= 1'b1; r_addr <= row_cnt_d1; r_wdata <= vec_updated;
                    end
                    if (row_cnt_d1 == M_limit) begin
                        state <= S_WRITE_U; row_cnt <= 0; r_we <= 0;
                    end else begin
                        row_cnt <= row_cnt + 1;
                        q_addr <= (current_i << 3) + row_cnt;
                        r_addr <= row_cnt;
                    end
                end

                S_WRITE_U: begin // L?u c?t U vào BRAM (?óng gói 4 ph?n t? Q13)
                    u_we <= 1'b1; u_addr <= (current_i << 2) + row_cnt;
                    u_wdata <= {u_col_buffer[(row_cnt<<2)+3], u_col_buffer[(row_cnt<<2)+2], 
                                u_col_buffer[(row_cnt<<2)+1], u_col_buffer[(row_cnt<<2)]};
                    if (row_cnt == 3) state <= S_DONE; else row_cnt <= row_cnt + 1;
                end

                S_DONE: begin
                    r_we <= 0; q_we <= 0; u_we <= 0; done_b <= 1; state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
