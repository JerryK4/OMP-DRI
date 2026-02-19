//`timescale 1ns / 1ps
//module qr_mgs_core #
//(
//parameter DW = 24,         // Q10.13
//parameter ADDR_W_PHI = 12, // 4096 rows
//parameter ADDR_W_Q = 8,    // 256 rows
//parameter DOT_W = 56
//)
//(
//input wire clk,
//input wire rst_n,
//input wire start_core,
//input wire [7:0] lambda_i,
//input wire [4:0] current_i,
//input wire [3:0] M_rows_in,   // Thêm input M_rows ?? h? tr? DRI (VD: 15 cho 16x16)
//// Giao ti?p Phi BRAM
//output reg [ADDR_W_PHI-1:0] phi_addr, // Chuy?n sang reg ?? control trong FSM
//input  wire [95:0]           phi_data,

//// Giao ti?p R BRAM
//output reg  [7:0]            r_addr_a,
//output reg                   r_we_a,
//output reg  [23:0]           r_din_a,

//// Giao ti?p Q BRAM
//output reg  [ADDR_W_Q-1:0]   q_addr_a,
//output reg                   q_we_a,
//output reg  [95:0]           q_din_a,
//output reg  [ADDR_W_Q-1:0]   q_addr_b,
//input  wire [95:0]           q_dout_b,

//output reg                   core_done
//);

//// --- FSM States ---
//localparam IDLE         = 4'd0,
//           LOAD_W       = 4'd1, 
//           J_LOOP_INIT  = 4'd2, 
//           CALC_RJI     = 4'd3, 
//           UPDATE_W_RD  = 4'd4, 
//           UPDATE_W_WR  = 4'd5, 
//           CALC_U       = 4'd6, 
//           CALC_ISR     = 4'd7, 
//           NORM_Q_RD    = 4'd8, 
//           NORM_Q_WR    = 4'd9, 
//           FINISH       = 4'd10;

//reg [3:0] state;
//reg [4:0] j_cnt;        
//reg [4:0] r_ptr, w_ptr; 
//reg [4:0] r_ptr_d1;     // Thanh ghi tr? ?? kh?p BRAM Latency
//reg signed [23:0] r_ji_reg, r_ii_reg;

//// --- RAM Buffer W ---
//reg  [3:0]  w_addr_a, w_addr_b;
//reg         w_we_a;
//reg  [95:0] w_din_a;
//wire [95:0] w_dout_b;

//w_buffer_ram u_w_buf (
//    .clka(clk), .addra(w_addr_a), .wea(w_we_a), .dina(w_din_a),
//    .clkb(clk), .addrb(w_addr_b), .doutb(w_dout_b)
//);

//// --- 1. Kh?i MAC (Dùng chung) ---
//wire start_mac = (state == CALC_RJI || state == CALC_U);
//wire mac_all_done; wire [DOT_W-1:0] mac_result; wire [3:0] mac_row_cnt;
//wire [95:0] mac_phi_in = (state == CALC_U) ? w_dout_b : q_dout_b; 
//wire [95:0] mac_res_in = w_dout_b;

//dot_product_4mac #(.DW(24), .OUT_W(56), .ROW_W(4)) u_mac (
//    .clk(clk), .rst_n(rst_n), .start_a(start_mac),
//    .N_cols(8'd0), .M_rows(M_rows_in), // Dùng input ??ng
//    .phi_data(mac_phi_in), .r_data(mac_res_in),
//    .dot_result(mac_result), .all_done(mac_all_done),
//    .row_cnt_out(mac_row_cnt), .phi_addr(), .r_addr()
//);

//// --- 2. Kh?i Multiplier Scalar ---
//reg [23:0] mul_scalar; reg [5:0] mul_shift; wire [95:0] mul_v_out;
//mul_scalar_4set #(.DW(24)) u_mul (
//    .clk(clk), .rst_n(rst_n), 
//    .v_in((state == NORM_Q_RD || state == NORM_Q_WR) ? w_dout_b : q_dout_b), 
//    .scalar(mul_scalar), .shift(mul_shift), .v_out(mul_v_out)
//);

//// --- 3. Kh?i Subtractor + Pipeline Alignment ---
//reg [95:0] delay_w [0:2];
//always @(posedge clk) begin
//    delay_w[0] <= w_dout_b;
//    delay_w[1] <= delay_w[0];
//    delay_w[2] <= delay_w[1];
//end
//wire [95:0] sub_v_out;
//sub_4set #(.DW(24)) u_sub (.clk(clk), .rst_n(rst_n), .a_vec(delay_w[2]), .b_vec(mul_v_out), .res_vec(sub_v_out));

//// --- 4. Kh?i Fast ISR ---
//wire isr_done;
//wire isr_start = (state == CALC_ISR); wire [23:0] isr_val;
//fast_isr u_isr (.clk(clk), .rst_n(rst_n), .start(isr_start), .u_in(mac_result), .y_out(isr_val), .done(isr_done));

//// Logic ?i?u ph?i Port B RAM Q và W
//always @(*) begin
//    q_addr_b = 0; w_addr_b = 0;
//    case (state)
//        LOAD_W:   w_addr_b = 0; // Tránh Collision khi ?ang Load
//        CALC_RJI, CALC_U: begin 
//            q_addr_b = (j_cnt << 4) + mac_row_cnt; 
//            w_addr_b = mac_row_cnt; 
//        end
//        UPDATE_W_RD, UPDATE_W_WR: begin 
//            q_addr_b = (j_cnt << 4) + r_ptr[3:0]; 
//            w_addr_b = r_ptr[3:0]; 
//        end
//        NORM_Q_RD, NORM_Q_WR: w_addr_b = r_ptr[3:0];
//        default: begin q_addr_b = 0; w_addr_b = 0; end
//    endcase
//end

//// --- Logic FSM Chính ---
//always @(posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//        state <= IDLE; core_done <= 0; w_we_a <= 0; q_we_a <= 0; r_we_a <= 0;
//        r_ptr <= 0; r_ptr_d1 <= 0; phi_addr <= 0;
//    end else begin
//        w_we_a <= 0; q_we_a <= 0; r_we_a <= 0; 

//        case (state)
//            IDLE: begin 
//                core_done <= 0; 
//                if (start_core) state <= LOAD_W; 
//                r_ptr <= 0; r_ptr_d1 <= 0;
//            end
            
//            LOAD_W: begin
//                // Address Phase (T)
//                if (r_ptr <= M_rows_in) begin
//                    phi_addr <= (lambda_i << 4) + r_ptr[3:0];
//                    r_ptr    <= r_ptr + 1;
//                end
                
//                // Data Phase (T+1): D? li?u t? Phi RAM v?, ghi vào Workspace
//                r_ptr_d1 <= r_ptr;
//                if (r_ptr > 0) begin
//                    w_we_a   <= 1;
//                    w_addr_a <= r_ptr_d1[3:0];
//                    w_din_a  <= phi_data;
//                end
                
//                // K?t thúc khi ?ã ghi ?? M_rows + 1 hàng
//                if (r_ptr_d1 == M_rows_in && w_we_a) begin 
//                    state <= J_LOOP_INIT; 
//                    r_ptr <= 0; 
//                end
//            end

//            J_LOOP_INIT: begin
//                if (current_i == 0) state <= CALC_U;
//                else begin j_cnt <= 0; state <= CALC_RJI; end
//            end

//            CALC_RJI: if (mac_all_done) begin 
//                r_ji_reg <= mac_result[13 +: 24]; 
//                state <= UPDATE_W_RD; 
//                r_ptr <= 0; w_ptr <= 0; 
//            end

//            UPDATE_W_RD: begin
//                mul_scalar <= r_ji_reg; mul_shift <= 6'd13;
//                // Address Phase
//                if (r_ptr <= M_rows_in) r_ptr <= r_ptr + 1;
                
//                // Data/Write Phase (Tr? 4 nh?p: 1 RAM + 2 Mul + 1 Sub)
//                if (r_ptr >= 4) begin 
//                    w_we_a   <= 1; 
//                    w_addr_a <= w_ptr[3:0]; 
//                    w_din_a  <= sub_v_out;
//                    // Ghi h? s? R vào BRAM (ch? c?n ghi 1 l?n ? hàng ??u)
//                    r_we_a   <= (w_ptr == 0); 
//                    r_addr_a <= (current_i << 4) + j_cnt; 
//                    r_din_a  <= r_ji_reg;
//                    w_ptr    <= w_ptr + 1;
//                end
                
//                if (w_ptr == M_rows_in && w_we_a) begin
//                    if (j_cnt == current_i - 1) state <= CALC_U; 
//                    else begin j_cnt <= j_cnt + 1; state <= CALC_RJI; end
//                    r_ptr <= 0; w_ptr <= 0;
//                end
//            end

//            CALC_U: if (mac_all_done) state <= CALC_ISR;
            
//            CALC_ISR: if (isr_done) begin 
//                r_ii_reg <= isr_val; 
//                state <= NORM_Q_RD; 
//                r_ptr <= 0; w_ptr <= 0; 
//            end

//            NORM_Q_RD: begin
//                mul_scalar <= r_ii_reg; mul_shift <= 6'd22;
//                if (r_ptr <= M_rows_in) r_ptr <= r_ptr + 1;
                
//                // Data/Write Phase (Tr? 3 nh?p: 1 RAM + 2 Mul)
//                if (r_ptr >= 3) begin 
//                    q_we_a   <= 1; 
//                    q_addr_a <= (current_i << 4) + w_ptr[3:0]; 
//                    q_din_a  <= mul_v_out;
//                    r_we_a   <= (w_ptr == 0); 
//                    r_addr_a <= (current_i << 4) + current_i; 
//                    r_din_a  <= r_ii_reg;
//                    w_ptr    <= w_ptr + 1;
//                end
//                if (w_ptr == M_rows_in && q_we_a) state <= FINISH;
//            end

//            FINISH: begin core_done <= 1; state <= IDLE; end
//            default: state <= IDLE;
//        endcase
//    end
//end
//endmodule

`timescale 1ns / 1ps

module qr_mgs_core #
(
    parameter DW = 24,
    parameter ADDR_W_PHI = 12,
    parameter ADDR_W_Q = 8,
    parameter DOT_W = 56
)
(
    input wire clk,
    input wire rst_n,
    input wire start_core,
    input wire [7:0] lambda_i,   
    input wire [4:0] current_i,  
    input wire [3:0] M_rows_in,   

    // Interface Phi BRAM
    output wire [ADDR_W_PHI-1:0] phi_addr,
    input  wire [95:0]           phi_data,

    // Interface R BRAM
    output reg  [7:0]            r_addr_a,
    output reg                   r_we_a,
    output reg  [23:0]           r_din_a,

    // Interface Q BRAM
    output reg  [ADDR_W_Q-1:0]   q_addr_a,
    output reg                   q_we_a,
    output reg  [95:0]           q_din_a,
    output reg  [ADDR_W_Q-1:0]   q_addr_b,
    input  wire [95:0]           q_dout_b,

    output reg [95:0]            qi_out,
    output reg                   core_done
);

    // --- States ---
    localparam IDLE=0, LOAD_W=1, J_INIT=2, TRG_MAC=3, WAIT_MAC=4, 
               RJI_SUB=5, TRG_U=6, WAIT_U=7, TRG_ISR=8, WAIT_ISR=9, 
               CALC_RII=10, NORM_Q=11, FINISH=12;

    reg [3:0] state;
    reg [4:0] j_cnt;
    reg [5:0] row_cnt; 
    reg signed [23:0] r_ji_reg, r_ii_reg;
    reg signed [79:0] rii_full;
    reg mac_start, isr_start;
    reg mac_done_latch;

    // Pipeline delay lines
    reg [3:0]  addr_del [0:7];
    reg        we_del   [0:7];
    reg [95:0] w_old_del [0:5];
    integer i_p;

    // Buffer W
    reg [3:0] w_addr_a, w_addr_b_mux; reg w_we_a; reg [95:0] w_din_a; wire [95:0] w_dout_b;
    w_buffer_ram u_w_buf (.clka(clk),.addra(w_addr_a),.wea(w_we_a),.dina(w_din_a),.clkb(clk),.addrb(w_addr_b_mux),.doutb(w_dout_b));

    // MAC
    wire [DOT_W-1:0] mac_res; wire mac_done_p, isr_done_p; wire [3:0] mac_r_addr;
    dot_product_4mac #(.ROW_W(4)) u_mac (.clk(clk),.rst_n(rst_n),.start_a(mac_start),.M_rows(4'd15),.N_cols(8'd0),
        .phi_data(w_dout_b), .r_data((state == WAIT_U)? w_dout_b : q_dout_b), 
        .dot_result(mac_res), .all_done(mac_done_p), .r_addr(mac_r_addr));

    // ISR & Tính toán
    wire [DW-1:0] isr_val;
    fast_isr u_isr (.clk(clk),.rst_n(rst_n),.start(isr_start),.u_in(mac_res),.y_out(isr_val),.done(isr_done_p));

    wire [95:0] mul_res, sub_res;
    reg [23:0] mul_scalar; reg [5:0] mul_shift;
    mul_scalar_4set u_mul (.clk(clk),.rst_n(rst_n),.v_in((state==NORM_Q)?w_dout_b:q_dout_b),.scalar(mul_scalar),.shift(mul_shift),.v_out(mul_res));
    sub_4set u_sub (.clk(clk),.rst_n(rst_n),.a_vec(w_old_del[3]),.b_vec(mul_res),.res_vec(sub_res));

    assign phi_addr = (state == LOAD_W) ? (lambda_i << 4) + row_cnt[3:0] : 12'h0;

    always @(*) begin
        q_addr_b = 8'hFF; w_addr_b_mux = 4'hF;
        case(state)
            WAIT_MAC, WAIT_U: begin q_addr_b = (j_cnt << 4) + mac_r_addr; w_addr_b_mux = mac_r_addr; end
            RJI_SUB, NORM_Q:  begin q_addr_b = (j_cnt << 4) + row_cnt[3:0]; w_addr_b_mux = row_cnt[3:0]; end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE; core_done <= 0; mac_start <= 0; isr_start <= 0; row_cnt <= 0; j_cnt <= 0;
            q_we_a <= 0; r_we_a <= 0; w_we_a <= 0; mac_done_latch <= 0;
            q_addr_a <= 0;qi_out <= 0; r_addr_a <= 0; r_din_a <= 0; q_din_a <= 0;
            // QUAN TR?NG: RESET M?NG ?? KH? L?I XX
            for(i_p=0; i_p<8; i_p=i_p+1) begin addr_del[i_p] <= 0; we_del[i_p] <= 0; end
            for(i_p=0; i_p<6; i_p=i_p+1) w_old_del[i_p] <= 0;
        end else begin
            q_we_a <= 0; r_we_a <= 0; w_we_a <= 0; core_done <= 0;
            mac_start <= 0; isr_start <= 0;
            if (mac_done_p) mac_done_latch <= 1;

            addr_del[0] <= row_cnt[3:0];
            we_del[0]   <= (state == LOAD_W || state == RJI_SUB || state == NORM_Q) && (row_cnt <= 15);
            for(i_p=1; i_p<8; i_p=i_p+1) begin addr_del[i_p] <= addr_del[i_p-1]; we_del[i_p] <= we_del[i_p-1]; end
            w_old_del[0] <= w_dout_b;
            for(i_p=1; i_p<6; i_p=i_p+1) w_old_del[i_p] <= w_old_del[i_p-1];

            case(state)
                IDLE: begin row_cnt <= 0; if(start_core) state <= LOAD_W; end

                LOAD_W: begin
                    w_we_a <= we_del[1]; w_addr_a <= addr_del[1]; w_din_a <= phi_data;
                    if(row_cnt >= 17) begin state <= J_INIT; row_cnt <= 0; end else row_cnt <= row_cnt + 1;
                end

                J_INIT: begin j_cnt <= 0; mac_done_latch <= 0; if(current_i == 0) state <= TRG_U; else state <= TRG_MAC; end

                TRG_MAC: begin mac_start <= 1; state <= WAIT_MAC; end
                WAIT_MAC: if(mac_done_latch) begin r_ji_reg <= mac_res[13 +: 24]; state <= RJI_SUB; row_cnt <= 0; mac_done_latch <= 0; end

                RJI_SUB: begin
                    mul_scalar <= r_ji_reg; mul_shift <= 13;
                    w_we_a <= we_del[5]; w_addr_a <= addr_del[5]; w_din_a <= sub_res;
                    r_we_a <= (row_cnt == 5); r_addr_a <= (current_i << 4) + j_cnt; r_din_a <= r_ji_reg;
                    if(row_cnt >= 22) begin row_cnt <= 0; if(j_cnt >= current_i - 1) state <= TRG_U; else begin j_cnt <= j_cnt + 1; state <= TRG_MAC; end end
                    else row_cnt <= row_cnt + 1;
                end

                TRG_U: begin mac_start <= 1; state <= WAIT_U; mac_done_latch <= 0; end
                WAIT_U: if(mac_done_latch) begin state <= TRG_ISR; mac_done_latch <= 0; end

                TRG_ISR: begin isr_start <= 1; state <= WAIT_ISR; end
                WAIT_ISR: if(isr_done_p) begin 
                    r_ii_reg <= isr_val; 
                    rii_full <= $signed(mac_res[39:0]) * $signed({1'b0, isr_val}); 
                    state <= CALC_RII; 
                end

                CALC_RII: begin state <= NORM_Q; row_cnt <= 0; end

                NORM_Q: begin
                    mul_scalar <= r_ii_reg; mul_shift <= 22;
                    q_we_a <= we_del[4]; q_addr_a <= (current_i << 4) + addr_del[4]; q_din_a <= mul_res;
                    if (we_del[4]) qi_out <= mul_res; 
                    r_we_a <= (row_cnt == 0); r_addr_a <= (current_i << 4) + current_i; r_din_a <= rii_full[35 +: 24]; 
                    if(row_cnt >= 20) begin core_done <= 1; state <= IDLE; end else row_cnt <= row_cnt + 1;
                end
            endcase
        end
    end
endmodule