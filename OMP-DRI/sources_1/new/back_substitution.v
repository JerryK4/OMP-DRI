//`timescale 1ns / 1ps

//module back_substitution (
//    input wire clk,
//    input wire rst_n,
//    input wire start_bsub,
//    input wire [4:0] K_final,      
    
//    input wire [3:0]  b_idx_in,
//    input wire [23:0] b_val_in,
//    input wire        b_we_in,

//    output reg [5:0]  u_addr,
//    input wire [95:0] u_rdata,

//    output reg [3:0]  x_idx,
//    output reg [23:0] x_val,
//    output reg        x_we,
//    output reg        done_bsub
//);

//    // --- 1. B? nh? n?i (Signed) ---
//    reg signed [23:0] b_buf [0:15];
//    reg signed [23:0] x_buf [0:15];

//    // --- 2. State Machine (M? r?ng tr?ng thái ?? b?o toàn ?? chính xác) ---
//    localparam S_IDLE       = 4'd0,
//               S_STORE_B    = 4'd1,
//               S_SUM_INIT   = 4'd2,
//               S_SUM_REQ    = 4'd3,
//               S_SUM_WAIT   = 4'd4,
//               S_SUM_ACC    = 4'd5,
//               S_DIV_REQ    = 4'd6,
//               S_DIV_WAIT   = 4'd7,
//               S_DIV_PREP   = 4'd8, // N?p d? li?u Q26 ?n ??nh
//               S_DIVIDE     = 4'd9, // B?t Start
//               S_WAIT_DIV   = 4'd10,
//               S_NEXT_ROW   = 4'd11,
//               S_OUT_X      = 4'd12,
//               S_DONE       = 4'd13;

//    reg [3:0] state;
//    reg signed [4:0] i_cnt, j_cnt;
//    reg signed [47:0] sum_acc; // Tích Q13*Q13 = Q26

//    // --- 3. IP Divider Generator (SIGNED 40-bit / 24-bit) ---
//    reg signed [39:0] div_dividend;
//    reg signed [23:0] div_divisor;
//    reg               div_start;
//    wire [63:0]       div_dout; // [63:24] Quotient, [23:0] Remainder
//    wire               div_valid;

//    div_gen_0 inst_div_final (
//        .aclk(clk), .aresetn(rst_n),
//        .s_axis_dividend_tdata(div_dividend), .s_axis_dividend_tvalid(div_start),
//        .s_axis_divisor_tdata(div_divisor),   .s_axis_divisor_tvalid(div_start),
//        .m_axis_dout_tdata(div_dout),         .m_axis_dout_tvalid(div_valid)
//    );

//    // Gi?i mã U[i,j] chu?n (D?a trên hàng i_cnt)
//    wire signed [23:0] u_ij_val = (i_cnt[1:0] == 2'b00) ? u_rdata[23:0] :
//                                  (i_cnt[1:0] == 2'b01) ? u_rdata[47:24] :
//                                  (i_cnt[1:0] == 2'b10) ? u_rdata[71:48] : u_rdata[95:72];

//    integer k;
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= S_IDLE; done_bsub <= 0; x_we <= 0; u_addr <= 0;
//            i_cnt <= 0; j_cnt <= 0; sum_acc <= 0; div_start <= 0;
//            div_dividend <= 0; div_divisor <= 0;
//            for(k=0; k<16; k=k+1) begin b_buf[k] <= 0; x_buf[k] <= 0; end
//        end else begin
//            case (state)
//                S_IDLE: begin
//                    done_bsub <= 0; x_we <= 0;
//                    if (b_we_in) b_buf[b_idx_in] <= b_val_in;
//                    if (start_bsub) begin
//                        state <= S_SUM_INIT;
//                        i_cnt <= K_final - 1; 
//                    end
//                end

//                S_STORE_B: begin
//                    if (b_we_in) b_buf[b_idx_in] <= b_val_in;
//                    if (start_bsub) begin
//                        state <= S_SUM_INIT;
//                        i_cnt <= K_final - 1;
//                    end
//                end

//                S_SUM_INIT: begin
//                    sum_acc <= 0;
//                    j_cnt <= K_final - 1; 
//                    state <= S_SUM_REQ;
//                end

//                S_SUM_REQ: begin
//                    if (j_cnt > i_cnt) begin
//                        u_addr <= (j_cnt << 2) + (i_cnt >> 2); 
//                        state  <= S_SUM_WAIT;
//                    end else state <= S_DIV_REQ;
//                end

//                S_SUM_WAIT: state <= S_SUM_ACC;

//                S_SUM_ACC: begin
//                    // Tính sum = sum + (Uij * xj) -> K?t qu? Q26
//                    sum_acc <= sum_acc + ($signed(u_ij_val) * $signed(x_buf[j_cnt]));
//                    j_cnt   <= j_cnt - 1;
//                    state   <= S_SUM_REQ;
//                end

//                S_DIV_REQ: begin
//                    u_addr <= (i_cnt << 2) + (i_cnt >> 2); 
//                    state <= S_DIV_WAIT;
//                end

//                S_DIV_WAIT: state <= S_DIV_PREP;

//                S_DIV_PREP: begin
//                    // TOÁN H?C QUY?T ??NH: (b_Q13 * 2^13 - sum_Q26) / U_Q13 = Result_Q13
//                    // Sign extension b_buf lên 40 bit r?i d?ch trái 13
//                    div_dividend <= ($signed({ {16{b_buf[i_cnt][23]}}, b_buf[i_cnt] }) << 13) - sum_acc[39:0];
//                    div_divisor  <= u_ij_val;
//                    state        <= S_DIVIDE;
//                end

//                S_DIVIDE: begin
//                    div_start <= 1'b1; 
//                    state     <= S_WAIT_DIV;
//                end

//                S_WAIT_DIV: begin
//                    div_start <= 0;
//                    if (div_valid) begin
//                        // L?y th??ng s? (Quotient) t? bit 24 tr? lên
//                        // V?i IP Divider Signed 40/24, bit [47:24] ch?a ?úng 24 bit Q13 ta c?n
//                        x_buf[i_cnt] <= div_dout[47:24]; 
//                        state <= S_NEXT_ROW;
//                    end
//                end

//                S_NEXT_ROW: begin
//                    if (i_cnt == 0) begin
//                        state <= S_OUT_X;
//                        i_cnt <= 0;
//                    end else begin
//                        i_cnt <= i_cnt - 1;
//                        state <= S_SUM_INIT;
//                    end
//                end

//                S_OUT_X: begin
//                    x_we  <= 1'b1;
//                    x_idx <= i_cnt[3:0];
//                    x_val <= x_buf[i_cnt]; 
//                    if (i_cnt == K_final - 1) state <= S_DONE;
//                    else i_cnt <= i_cnt + 1;
//                end

//                S_DONE: begin
//                    x_we <= 0; done_bsub <= 1; state <= S_IDLE;
//                end
//            endcase
//        end
//    end
//endmodule



//`timescale 1ns / 1ps

//module back_substitution (
//    input wire clk,
//    input wire rst_n,
//    input wire start_bsub,
//    input wire [4:0] K_final,      
    
//    input wire [3:0]  b_idx_in,
//    input wire [23:0] b_val_in,
//    input wire        b_we_in,

//    output reg [5:0]  u_addr,
//    input wire [95:0] u_rdata,

//    output reg [3:0]  x_idx,
//    output reg [23:0] x_val,
//    output reg        x_we,
//    output reg        done_bsub
//);

//    // --- 1. B? nh? n?i (Signed) ---
//    reg signed [23:0] b_buf [0:15];
//    reg signed [23:0] x_buf [0:15];

//    // --- 2. State Machine (C?n ch?nh nh?p chu?n) ---
//    localparam S_IDLE       = 4'd0,
//               S_STORE_B    = 4'd1,
//               S_SUM_INIT   = 4'd2,
//               S_SUM_REQ    = 4'd3,
//               S_SUM_WAIT   = 4'd4,
//               S_SUM_ACC    = 4'd5,
//               S_SUM_DONE   = 4'd6,
//               S_DIV_REQ    = 4'd7,
//               S_DIV_WAIT   = 4'd8,
//               S_DIV_PREP   = 4'd9, 
//               S_DIVIDE     = 4'd10,
//               S_WAIT_DIV   = 4'd11,
//               S_NEXT_ROW   = 4'd12,
//               S_OUT_X      = 4'd13,
//               S_DONE       = 4'd14;

//    reg [3:0] state;
//    reg signed [4:0] i_cnt, j_cnt;
//    reg signed [47:0] sum_acc; // Gi? nguyên ??nh d?ng Q26 ??y ??

//    // --- 3. IP Divider Generator (SIGNED 40-bit / 24-bit / Fractional 24) ---
//    reg signed [39:0] div_dividend;
//    reg signed [23:0] div_divisor;
//    reg               div_start;
//    wire [63:0]       div_dout; 
//    wire              div_valid;

//    div_gen_0 inst_div_final (
//        .aclk(clk), .aresetn(rst_n),
//        .s_axis_dividend_tdata(div_dividend), .s_axis_dividend_tvalid(div_start),
//        .s_axis_divisor_tdata(div_divisor),   .s_axis_divisor_tvalid(div_start),
//        .m_axis_dout_tdata(div_dout),         .m_axis_dout_tvalid(div_valid)
//    );

//    // Gi?i mã U[i,j] 
//    wire signed [23:0] u_ij_val = (i_cnt[1:0] == 2'b00) ? u_rdata[23:0] :
//                                  (i_cnt[1:0] == 2'b01) ? u_rdata[47:24] :
//                                  (i_cnt[1:0] == 2'b10) ? u_rdata[71:48] : u_rdata[95:72];

//    integer k;
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= S_IDLE; done_bsub <= 0; x_we <= 0; u_addr <= 0;
//            i_cnt <= 0; j_cnt <= 0; sum_acc <= 0; div_start <= 0;
//            for(k=0; k<16; k=k+1) begin b_buf[k] <= 0; x_buf[k] <= 0; end
//        end else begin
//            case (state)
//                S_IDLE: begin
//                    done_bsub <= 0; x_we <= 0;
//                    if (b_we_in) b_buf[b_idx_in] <= b_val_in;
//                    if (start_bsub) begin state <= S_SUM_INIT; i_cnt <= K_final - 1; end
//                end

//                S_STORE_B: begin
//                    if (b_we_in) b_buf[b_idx_in] <= b_val_in;
//                    if (start_bsub) begin state <= S_SUM_INIT; i_cnt <= K_final - 1; end
//                end

//                S_SUM_INIT: begin
//                    sum_acc <= 48'd0; j_cnt <= K_final - 1; state <= S_SUM_REQ;
//                end

//                S_SUM_REQ: begin
//                    if (j_cnt > i_cnt) begin
//                        u_addr <= (j_cnt << 2) + (i_cnt >> 2); state  <= S_SUM_WAIT;
//                    end else state <= S_SUM_DONE;
//                end

//                S_SUM_WAIT: state <= S_SUM_ACC;

//                S_SUM_ACC: begin
//                    // TÍNH TOÁN Q26: sum = sum + (Q13 * Q13)
//                    sum_acc <= sum_acc + ($signed(u_ij_val) * $signed(x_buf[j_cnt]));
//                    j_cnt   <= j_cnt - 1;
//                    state   <= S_SUM_REQ;
//                end

//                S_SUM_DONE: state <= S_DIV_REQ;

//                S_DIV_REQ: begin
//                    u_addr <= (i_cnt << 2) + (i_cnt >> 2); state <= S_DIV_WAIT;
//                end

//                S_DIV_WAIT: state <= S_DIV_PREP;

//                S_DIV_PREP: begin
//                    // TOÁN H?C QUY?T ??NH: (b_Q13 * 2^13 - sum_Q26) / U_Q13 = Result_Q13
//                    // ??a b v? Q26 r?i th?c hi?n phép tr? toàn ph?n
//                    div_dividend <= ($signed({ {16{b_buf[i_cnt][23]}}, b_buf[i_cnt] }) << 13) - sum_acc[39:0];
//                    div_divisor  <= u_ij_val;
//                    state        <= S_DIVIDE;
//                end

//                S_DIVIDE: begin
//                    div_start <= 1'b1; 
//                    state     <= S_WAIT_DIV;
//                end

//                S_WAIT_DIV: begin
//                    div_start <= 0;
//                    if (div_valid) begin
//                        // L?y d?i bit Quotient t? IP Fractional 24-bit
//                        x_buf[i_cnt] <= div_dout[47:24]; 
//                        state <= S_NEXT_ROW;
//                    end
//                end

//                S_NEXT_ROW: begin
//                    if (i_cnt == 0) begin state <= S_OUT_X; i_cnt <= 0; end
//                    else begin i_cnt <= i_cnt - 1; state <= S_SUM_INIT; end
//                end

//                S_OUT_X: begin
//                    x_we  <= 1'b1; x_idx <= i_cnt[3:0]; x_val <= x_buf[i_cnt]; 
//                    if (i_cnt == K_final - 1) state <= S_DONE; else i_cnt <= i_cnt + 1;
//                end

//                S_DONE: begin x_we <= 0; done_bsub <= 1; state <= S_IDLE; end
                
//                default: state <= S_IDLE;
//            endcase
//        end
//    end
//endmodule

`timescale 1ns / 1ps

module back_substitution (
    input wire clk,
    input wire rst_n,
    input wire start_bsub,
    input wire [4:0] K_final,      
    
    input wire [3:0]  b_idx_in,
    input wire [23:0] b_val_in,
    input wire        b_we_in,

    output reg [5:0]  u_addr,
    input wire [95:0] u_rdata,

    output reg [3:0]  x_idx,
    output reg [23:0] x_val,
    output reg        x_we,
    output reg        done_bsub
);

    reg signed [23:0] b_buf [0:15];
    reg signed [23:0] x_buf [0:15];

    localparam S_IDLE       = 4'd0,
               S_STORE_B    = 4'd1,
               S_SUM_INIT   = 4'd2,
               S_SUM_REQ    = 4'd3,
               S_SUM_WAIT   = 4'd4,
               S_SUM_ACC    = 4'd5,
               S_SUM_DONE   = 4'd6,
               S_DIV_REQ    = 4'd7,
               S_DIV_WAIT   = 4'd8,
               S_DIV_PREP   = 4'd9, 
               S_DIVIDE     = 4'd10,
               S_WAIT_DIV   = 4'd11,
               S_NEXT_ROW   = 4'd12,
               S_OUT_X      = 4'd13,
               S_DONE       = 4'd14;

    reg [3:0] state;
    reg signed [4:0] i_cnt, j_cnt;
    reg signed [47:0] sum_acc; 

    // --- IP Divider Generator (SIGNED 40/24) ---
    reg signed [39:0] div_dividend;
    reg signed [23:0] div_divisor;
    reg               div_start;
    wire [63:0]       div_dout; 
    wire              div_valid;

    div_gen_0 inst_div_final (
        .aclk(clk), .aresetn(rst_n),
        .s_axis_dividend_tdata(div_dividend), .s_axis_dividend_tvalid(div_start),
        .s_axis_divisor_tdata(div_divisor),   .s_axis_divisor_tvalid(div_start),
        .m_axis_dout_tdata(div_dout),         .m_axis_dout_tvalid(div_valid)
    );

    wire signed [23:0] u_ij_val = (i_cnt[1:0] == 2'b00) ? u_rdata[23:0] :
                                  (i_cnt[1:0] == 2'b01) ? u_rdata[47:24] :
                                  (i_cnt[1:0] == 2'b10) ? u_rdata[71:48] : u_rdata[95:72];

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; done_bsub <= 0; x_we <= 0; u_addr <= 0;
            i_cnt <= 0; j_cnt <= 0; sum_acc <= 0; div_start <= 0;
            for(k=0; k<16; k=k+1) begin b_buf[k] <= 0; x_buf[k] <= 0; end
        end else begin
            case (state)
                S_IDLE: begin
                    done_bsub <= 0; x_we <= 0;
                    if (b_we_in) b_buf[b_idx_in] <= b_val_in;
                    if (start_bsub) begin state <= S_SUM_INIT; i_cnt <= K_final - 1; end
                end

                S_STORE_B: begin
                    if (b_we_in) b_buf[b_idx_in] <= b_val_in;
                    if (start_bsub) begin state <= S_SUM_INIT; i_cnt <= K_final - 1; end
                end

                S_SUM_INIT: begin
                    sum_acc <= 48'd0; j_cnt <= K_final - 1; state <= S_SUM_REQ;
                end

                S_SUM_REQ: begin
                    if (j_cnt > i_cnt) begin
                        u_addr <= (j_cnt << 2) + (i_cnt >> 2); state  <= S_SUM_WAIT;
                    end else state <= S_SUM_DONE;
                end

                S_SUM_WAIT: state <= S_SUM_ACC;

                S_SUM_ACC: begin
                    sum_acc <= sum_acc + ($signed(u_ij_val) * $signed(x_buf[j_cnt]));
                    j_cnt   <= j_cnt - 1;
                    state   <= S_SUM_REQ;
                end

                S_SUM_DONE: state <= S_DIV_REQ;

                S_DIV_REQ: begin
                    u_addr <= (i_cnt << 2) + (i_cnt >> 2); state <= S_DIV_WAIT;
                end

                S_DIV_WAIT: state <= S_DIV_PREP;

                S_DIV_PREP: begin
                    // TOÁN H?C CHU?N: (b_Q13 * 2^13 - sum_Q26) / U_Q13
                    div_dividend <= ($signed({ {16{b_buf[i_cnt][23]}}, b_buf[i_cnt] }) << 13) - sum_acc[39:0];
                    div_divisor  <= u_ij_val;
                    state        <= S_DIVIDE;
                end

                S_DIVIDE: begin
                    div_start <= 1'b1; state <= S_WAIT_DIV;
                end

                S_WAIT_DIV: begin
                    div_start <= 0;
                    if (div_valid) begin
                        // L?y d?i bit [47:24] cho Quotient 24-bit c?a IP 40/24 Fractional
                        x_buf[i_cnt] <= div_dout[47:24]; 
                        state <= S_NEXT_ROW;
                    end
                end

                S_NEXT_ROW: begin
                    if (i_cnt == 0) begin state <= S_OUT_X; i_cnt <= 0; end
                    else begin i_cnt <= i_cnt - 1; state <= S_SUM_INIT; end
                end

                S_OUT_X: begin
                    x_we <= 1'b1; x_idx <= i_cnt[3:0]; x_val <= x_buf[i_cnt]; 
                    if (i_cnt == K_final - 1) state <= S_DONE; else i_cnt <= i_cnt + 1;
                end

                S_DONE: begin x_we <= 0; done_bsub <= 1; state <= S_IDLE; end
            endcase
        end
    end
endmodule