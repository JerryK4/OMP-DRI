//`timescale 1ns / 1ps

//module dot_product_4mac #
//(
//    parameter ADDR_W = 12,    
//    parameter ROW_W  = 6,     
//    parameter COL_W  = 8,     
//    parameter ROW_N  = 4,     
//    parameter DW     = 24,    // 24-bit signed Q10.13
//    parameter ACC_W  = 56,    
//    parameter OUT_W  = 56     // Xu?t 56-bit ?? b? Finding Max so sánh chính xác nh?t
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start_a,      

//    input  wire [COL_W-1:0] N_cols, // VD: 255
//    input  wire [ROW_W-1:0] M_rows, // VD: 15

//    output reg  [ADDR_W-1:0] phi_addr, 
//    input  wire [4*DW-1:0]   phi_data, 

//    output reg  [ROW_W-1:0]  r_addr, 
//    input  wire [4*DW-1:0]   r_data,   

//    output reg  [OUT_W-1:0]  dot_result, 
//    output reg  [COL_W-1:0]  current_col_idx,
//    output wire [ROW_W-1:0]  row_cnt_out,
//    output reg               col_done, 
//    output reg               all_done  
//);

//    /* ===============================
//       FSM states
//    =============================== */
//    localparam IDLE      = 3'd0;
//    localparam INIT_COL  = 3'd1; 
//    localparam WAIT_RAM  = 3'd2; 
//    localparam ACCUM     = 3'd3; 
//    localparam SAVE_RES  = 3'd4; // Tính toán giá tr? cu?i
//    localparam HOLD_RES  = 3'd5; // Tr?ng thái m?i: Ch?t d? li?u và báo Done
//    localparam FINISH    = 3'd6;

//    reg [2:0] state;
//    reg [ROW_W-1:0] row_cnt; 
//    reg [COL_W-1:0] col_cnt; 
//    reg signed [ACC_W-1:0] accumulator;

//    /* ===============================
//       Unpack data (Signed 24-bit)
//    =============================== */
//    wire signed [DW-1:0] p0, p1, p2, p3;
//    wire signed [DW-1:0] r0, r1, r2, r3;

//    assign {p3, p2, p1, p0} = phi_data;
//    assign {r3, r2, r1, r0} = r_data;
//    assign row_cnt_out = row_cnt;

//    /* ===============================
//       Logic chính (FSM)
//    =============================== */
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin    
//            state <= IDLE;
//            phi_addr <= 0; r_addr <= 0;
//            accumulator <= 0;
//            col_done <= 0; all_done <= 0;
//            row_cnt <= 0; col_cnt <= 0;
//            current_col_idx <= 0; dot_result <= 0;
//        end else begin
//            case(state) 

//                IDLE: begin
//                    all_done <= 0;
//                    col_done <= 0;
//                    if(start_a) begin    
//                        state <= INIT_COL;
//                        col_cnt <= 0;
//                    end
//                end 

//                INIT_COL: begin
//                    row_cnt     <= 0;
//                    accumulator <= 0;
//                    col_done    <= 0;
//                    phi_addr    <= (col_cnt << ROW_N); 
//                    r_addr      <= 0;
//                    state       <= WAIT_RAM;
//                end

//                WAIT_RAM: begin
//                    // Latency = 1: Phát ??a ch? hàng 1 trong khi hàng 0 ?ang v?
//                    row_cnt  <= 4'd1;
//                    r_addr   <= 4'd1;
//                    phi_addr <= (col_cnt << ROW_N) + 4'd1;
//                    state    <= ACCUM;
//                end 

//                ACCUM: begin
//                    // Tính MAC cho hàng (row_cnt - 1)
//                    accumulator <= accumulator +
//                        ($signed(p0) * $signed(r0)) +
//                        ($signed(p1) * $signed(r1)) +
//                        ($signed(p2) * $signed(r2)) +
//                        ($signed(p3) * $signed(r3));

//                    if (row_cnt == M_rows) begin
//                        state <= SAVE_RES;
//                    end else begin
//                        row_cnt  <= row_cnt + 1'b1;
//                        r_addr   <= row_cnt + 1'b1;
//                        phi_addr <= (col_cnt << ROW_N) + (row_cnt + 1'b1);
//                    end
//                end
////                WAIT_RAM: begin
////                    // Gi? nguyên ??a ch? 0 ? ?ây, không t?ng lên 1 v?i
////                    // ?? nh?p sau vào ACCUM, d? li?u hàng 0 m?i b?t ??u xu?t hi?n
////                    state    <= ACCUM;
////                    row_cnt  <= 0; // B?t ??u ??m t? 0
////                end 

////                ACCUM: begin
////                    // Nh?p ??u tiên c?a ACCUM s? dùng d? li?u hàng 0
////                    accumulator <= accumulator +
////                        ($signed(p0) * $signed(r0)) +
////                        ($signed(p1) * $signed(r1)) +
////                        ($signed(p2) * $signed(r2)) +
////                        ($signed(p3) * $signed(r3));

////                    if (row_cnt == M_rows) begin
////                        state <= SAVE_RES;
////                    end else begin
////                        row_cnt  <= row_cnt + 1'b1;
////                        r_addr   <= row_cnt + 1'b1; // T?ng ??a ch? cho nh?p sau
////                        phi_addr <= (col_cnt << ROW_N) + (row_cnt + 1'b1);
////                    end
////                end

//                SAVE_RES: begin
//                    // Tính n?t hàng cu?i cùng và gán vào dot_result
//                    dot_result <= accumulator + 
//                                  (($signed(p0) * $signed(r0)) + ($signed(p1) * $signed(r1)) + 
//                                   ($signed(p2) * $signed(r2)) + ($signed(p3) * $signed(r3)));
//                    current_col_idx <= col_cnt;
//                    state <= HOLD_RES; // Chuy?n sang Hold ?? báo col_done
//                end

//                HOLD_RES: begin
//                    col_done <= 1'b1; // T?i chu k? này dot_result ?ã ?n ??nh hoàn toàn
//                    if (col_cnt == N_cols)
//                        state <= FINISH;
//                    else begin
//                        col_cnt <= col_cnt + 1'b1;
//                        state   <= INIT_COL;
//                    end
//                end

//                FINISH: begin
//                    col_done <= 0;
//                    all_done <= 1'b1;
//                    state    <= IDLE;
//                end 

//                default: state <= IDLE;
//            endcase
//        end
//    end

//endmodule


`timescale 1ns / 1ps

module dot_product_4mac #
(
    parameter ADDR_W = 12,    
    parameter ROW_W  = 6,     
    parameter COL_W  = 8,     
    parameter ROW_N  = 4,     
    parameter DW     = 24,    // Q10.13 signed
    parameter ACC_W  = 56,    
    parameter OUT_W  = 56     
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start_a,      

    input  wire [COL_W-1:0] N_cols, 
    input  wire [ROW_W-1:0] M_rows, 

    output reg  [ADDR_W-1:0] phi_addr, 
    input  wire [4*DW-1:0]   phi_data, 

    output reg  [ROW_W-1:0]  r_addr, 
    input  wire [4*DW-1:0]   r_data,   

    output reg  [OUT_W-1:0]  dot_result, 
    output reg  [COL_W-1:0]  current_col_idx,
    output wire [ROW_W-1:0]  row_cnt_out,
    output reg               col_done, 
    output reg               all_done  
);

    // --- Các tr?ng thái FSM ---
    localparam IDLE      = 2'd0,
               RUN_COL   = 2'd1, // Tr?ng thái quét hàng và tích l?y
               HOLD_RES  = 2'd2, // Ch?t k?t qu? và báo Done c?t
               FINISH    = 2'd3;

    reg [1:0] state;
    reg [ROW_W-1:0] row_ptr;    // Con tr? phát ??a ch?
    reg [COL_W-1:0] col_ptr;    // Con tr? duy?t c?t
    reg signed [ACC_W-1:0] acc; // B? tích l?y
    reg pipe_vld;               // C? báo d? li?u trên bus là h?p l? (Tr? 1 nh?p so v?i Addr)

    // Unpack d? li?u signed t? bus 96-bit
    wire signed [DW-1:0] p0, p1, p2, p3;
    wire signed [DW-1:0] r0, r1, r2, r3;
    assign {p3, p2, p1, p0} = phi_data;
    assign {r3, r2, r1, r0} = r_data;
    
    assign row_cnt_out = row_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            phi_addr <= 0; r_addr <= 0;
            acc <= 0; pipe_vld <= 0;
            col_done <= 0; all_done <= 0;
            row_ptr <= 0; col_ptr <= 0;
            current_col_idx <= 0; dot_result <= 0;
        end else begin
            col_done <= 0; // M?c ??nh pulse v? 0

            case (state)
                IDLE: begin
                    all_done <= 0;
                    if (start_a) begin
                        state    <= RUN_COL;
                        col_ptr  <= 0;
                        row_ptr  <= 0;
                        acc      <= 0;
                        pipe_vld <= 0;
                        // Phát ??a ch? hàng 0 ngay l?p t?c
                        phi_addr <= (0 << ROW_N); 
                        r_addr   <= 0;
                    end
                end

                RUN_COL: begin
                    // 1. GIAI ?O?N PHÁT ??A CH? (Address Phase)
                    if (row_ptr < M_rows) begin
                        row_ptr  <= row_ptr + 1'b1;
                        phi_addr <= (col_ptr << ROW_N) + (row_ptr + 1'b1);
                        r_addr   <= row_ptr + 1'b1;
                        pipe_vld <= 1'b1;
                    end else begin
                        pipe_vld <= 1'b0; // ?ã phát h?t ??a ch? cho c?t này
                    end

                    // 2. GIAI ?O?N TÍCH L?Y (Data Phase - Tr? 1 nh?p)
                    // ? nh?p này, data c?a ??a ch? nh?p tr??c ?ã v? t?i bus
                    if (pipe_vld || (row_ptr > 0 && row_ptr <= M_rows)) begin
                        acc <= acc + 
                               ($signed(p0) * $signed(r0)) +
                               ($signed(p1) * $signed(r1)) +
                               ($signed(p2) * $signed(r2)) +
                               ($signed(p3) * $signed(r3));
                    end

                    // 3. KI?M TRA K?T THÚC C?T
                    // Sau khi hàng cu?i (M_rows) ???c c?ng xong
                    if (!pipe_vld && row_ptr == M_rows) begin
                        state <= HOLD_RES;
                    end
                end

                HOLD_RES: begin
                    dot_result      <= acc;
                    current_col_idx <= col_ptr;
                    col_done        <= 1'b1; // B?t pulse báo cho b? Finding Max
                    
                    if (col_ptr == N_cols) begin
                        state <= FINISH;
                    end else begin
                        // Reset chu?n b? cho c?t ti?p theo
                        col_ptr  <= col_ptr + 1'b1;
                        row_ptr  <= 0;
                        acc      <= 0;
                        pipe_vld <= 0;
                        phi_addr <= ((col_ptr + 1'b1) << ROW_N);
                        r_addr   <= 0;
                        state    <= RUN_COL;
                    end
                end

                FINISH: begin
                    all_done <= 1'b1;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule