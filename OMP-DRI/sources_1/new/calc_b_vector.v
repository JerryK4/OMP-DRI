//`timescale 1ns / 1ps

//module calc_b_vector (
//    input wire clk,
//    input wire rst_n,
//    input wire start_calc_b,
//    input wire [4:0] K_final,     
//    input wire [2:0] M_limit,     

//    // Giao ti?p BRAM
//    output reg [6:0]  q_addr,
//    input wire [95:0] q_rdata,
//    output reg [2:0]  y_addr,
//    input wire [95:0] y_data,

//    // ??u ra vector b
//    output reg [3:0]  b_idx,
//    output reg [23:0] b_val,
//    output reg        b_we,
//    output reg        done_b_vec
//);

//    // --- 1. Máy tr?ng thái (FSM) ---
//    localparam S_IDLE       = 3'd0,
//               S_REQ_DATA   = 3'd1, 
//               S_WAIT_BRAM  = 3'd2, 
//               S_ACCUM      = 3'd3, 
//               S_WAIT_LAST  = 3'd4, // M?I: ??i Accumulator ch?t nh?p cu?i
//               S_SAVE_BK    = 3'd5, 
//               S_PULSE_WAIT = 3'd6, 
//               S_DONE       = 3'd7;

//    reg [2:0] state;
//    reg [4:0] k_cnt;   
//    reg [2:0] row_cnt; 
//    reg signed [63:0] accumulator;

//    // --- 2. Module lõi MAC song song ---
//    wire [47:0] dot_out_4;
//    mac_4_parallel inst_mac_b (
//        .a0(q_rdata[23:0]),  .a1(q_rdata[47:24]), .a2(q_rdata[71:48]), .a3(q_rdata[95:72]),
//        .b0(y_data[23:0]),   .b1(y_data[47:24]),  .b2(y_data[71:48]),  .b3(y_data[95:72]),
//        .sum_out(dot_out_4)
//    );

//    // --- 3. Logic ?i?u khi?n ---
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= S_IDLE; q_addr <= 0; y_addr <= 0;
//            k_cnt <= 0; row_cnt <= 0; accumulator <= 0;
//            b_we <= 0; b_idx <= 0; b_val <= 0; done_b_vec <= 0;
//        end else begin
//            case (state)
//                S_IDLE: begin
//                    done_b_vec <= 0; b_we <= 0;
//                    if (start_calc_b) begin
//                        state <= S_REQ_DATA;
//                        k_cnt <= 0; row_cnt <= 0; accumulator <= 0;
//                        q_addr <= 0; y_addr <= 0; 
//                    end
//                end

//                S_REQ_DATA: state <= S_WAIT_BRAM;

//                S_WAIT_BRAM: state <= S_ACCUM;

//                S_ACCUM: begin
//                    // C?ng d?n k?t qu? MAC
//                    accumulator <= accumulator + $signed(dot_out_4);

//                    if (row_cnt == M_limit) begin
//                        state <= S_WAIT_LAST; // Chuy?n sang ??i nh?p cu?i
//                    end else begin
//                        row_cnt <= row_cnt + 1;
//                        q_addr <= (k_cnt << 3) + (row_cnt + 1);
//                        y_addr <= row_cnt + 1;
//                    end
//                end

//                S_WAIT_LAST: begin
//                    // Nh?p này không làm gì, ch? ?? accumulator <= accumulator + last_dot_out th?c hi?n xong
//                    state <= S_SAVE_BK;
//                end

//                S_SAVE_BK: begin
//                    b_we  <= 1'b1;
//                    b_idx <= k_cnt[3:0];
//                    // Trích xu?t Q13 chu?n t? accumulator Q26
//                    b_val <= accumulator[36:13]; 
//                    state <= S_PULSE_WAIT;
//                end

//                S_PULSE_WAIT: begin
//                    b_we <= 1'b0;
//                    if (k_cnt == K_final - 1) begin
//                        state <= S_DONE;
//                    end else begin
//                        k_cnt <= k_cnt + 1;
//                        row_cnt <= 0;
//                        accumulator <= 0;
//                        q_addr <= (k_cnt + 1) << 3; // Nh?y sang c?t Q ti?p theo
//                        y_addr <= 0;
//                        state <= S_REQ_DATA;
//                    end
//                end

//                S_DONE: begin
//                    done_b_vec <= 1;
//                    state <= S_IDLE;
//                end

//                default: state <= S_IDLE;
//            endcase
//        end
//    end
//endmodule

`timescale 1ns / 1ps

module calc_b_vector (
    input wire clk,
    input wire rst_n,
    input wire start_calc_b,
    input wire [4:0] K_final,     // S? c?t Q th?c t? c?n tính (final_i + 1)
    input wire [2:0] M_limit,     // DRI: 1 (4x4) ho?c 7 (8x8)

    // Giao ti?p BRAM Q (??c)
    output reg [6:0]  q_addr,
    input wire [95:0] q_rdata,

    // Giao ti?p BRAM y (??c)
    output reg [2:0]  y_addr,
    input wire [95:0] y_data,

    // ??u ra k?t qu? vector b
    output reg [3:0]  b_idx,
    output reg [23:0] b_val,
    output reg        b_we,
    output reg        done_b_vec
);

    // --- 1. Máy tr?ng thái (FSM) ---
    localparam S_IDLE       = 3'd0;
    localparam S_REQ_DATA   = 3'd1; 
    localparam S_WAIT_BRAM  = 3'd2; 
    localparam S_ACCUM      = 3'd3; 
    localparam S_SAVE_BK    = 3'd4; // Tr?ng thái ch?t d? li?u và b?t b_we
    localparam S_PULSE_WAIT = 3'd5; // Tr?ng thái m?i: H? b_we và chu?n b? c?t ti?p theo
    localparam S_DONE       = 3'd6;

    reg [2:0] state;
    reg [4:0] k_cnt;   
    reg [2:0] row_cnt; 
    reg signed [63:0] accumulator;

    // --- 2. Module lõi MAC song song ---
    wire [47:0] dot_out_4;
    mac_4_parallel inst_mac_b (
        .a0(q_rdata[23:0]),  .a1(q_rdata[47:24]), .a2(q_rdata[71:48]), .a3(q_rdata[95:72]),
        .b0(y_data[23:0]),   .b1(y_data[47:24]),  .b2(y_data[71:48]),  .b3(y_data[95:72]),
        .sum_out(dot_out_4)
    );

    // --- 3. Logic ?i?u khi?n ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            q_addr <= 0; y_addr <= 0;
            k_cnt <= 0; row_cnt <= 0;
            accumulator <= 0;
            b_we <= 0; b_idx <= 0; b_val <= 0;
            done_b_vec <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done_b_vec <= 0;
                    b_we <= 0;
                    if (start_calc_b) begin
                        state <= S_REQ_DATA;
                        k_cnt <= 0; row_cnt <= 0;
                        accumulator <= 0;
                        // G?i ??a ch? ??u tiên (Row 0)
                        q_addr <= 0; 
                        y_addr <= 0; 
                    end
                end

                S_REQ_DATA: begin
                    state <= S_WAIT_BRAM;
                end

                S_WAIT_BRAM: begin
                    state <= S_ACCUM;
                end

                S_ACCUM: begin
                    // C?ng d?n 4 ph?n t? song song vào b? tích l?y 64-bit
                    accumulator <= accumulator + $signed(dot_out_4);

                    if (row_cnt == M_limit) begin
                        state <= S_SAVE_BK;
                    end else begin
                        row_cnt <= row_cnt + 1;
                        // G?i ??a ch? ti?p theo (Stride 8 cho ma tr?n Q)
                        q_addr <= (k_cnt << 3) + (row_cnt + 1);
                        y_addr <= row_cnt + 1;
                    end
                end

                S_SAVE_BK: begin
                    // B??c này ch? di?n ra trong 1 chu k? clk
                    b_we <= 1'b1;           // B?t l?nh ghi cho module sau
                    b_idx <= k_cnt[3:0];
                    b_val <= accumulator[36:13]; // Ch?t giá tr? Q10.13
                    state <= S_PULSE_WAIT;  // Nh?y sang tr?ng thái h? WE ngay l?p t?c
                end

                S_PULSE_WAIT: begin
                    b_we <= 1'b0;           // H? WE (Quan tr?ng nh?t)
                    
                    if (k_cnt == K_final - 1) begin
                        state <= S_DONE;
                    end else begin
                        k_cnt <= k_cnt + 1;
                        row_cnt <= 0;
                        accumulator <= 0;
                        // Tính ??a ch? hàng 0 c?a c?t ti?p theo trong Q BRAM
                        q_addr <= (k_cnt + 1) << 3; 
                        y_addr <= 0;
                        state <= S_REQ_DATA;
                    end
                end

                S_DONE: begin
                    done_b_vec <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule