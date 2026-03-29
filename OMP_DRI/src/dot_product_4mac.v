`timescale 1ns / 1ps

module dot_product_4mac #
(
    // --- S?a: Thêm tham s? NUM_MAC (S? b? MAC song song) ---
    parameter NUM_MAC = 4,    // S?a: S? l??ng b? MAC ho?t ??ng song song.
                              //      (Hi?n t?i logic code s? d?ng 4 b? MAC)

    // --- S?a: Các tham s? kích th??c phù h?p v?i ?nh 16x16 ---
    // (Các giá tr? này ???c gi? nguyên nh? trong code g?c c?a b?n,
    //  chúng ?ã có ?? ?? r?ng cho ?nh 16x16 và logic 4 MAC)
    parameter ADDR_W = 12,    // Chi?u r?ng ??a ch? cho phi_addr. V?i 16x16,
                              // t?ng s? packed memory locations là (64*256)/4 = 4096.
                              // log2(4096) = 12, nên ADDR_W = 12 là phù h?p.
    parameter COL_W  = 8,     // Chi?u r?ng cho N_cols (max 255 cho ?nh 16x16),
                              // log2(256) = 8, nên COL_W = 8 là phù h?p.
    parameter ROW_W  = 6,     // Chi?u r?ng cho M_rows (max 16 cho 64/4 packed rows).
                              // log2(16) = 4, nh?ng ROW_W = 6 cung c?p headroom an toàn.
    parameter ROW_N  = 4,     // S?a: log2 c?a s? hàng v?t lý/packed row m?i c?t.
                              //      V?i M=64 và NUM_MAC=4, m?i c?t có 64/4 = 16 packed rows.
                              //      log2(16) = 4, nên ROW_N = 4 là phù h?p.
    
    // --- Tham s? d? li?u ---
    parameter DW     = 24,    // Chi?u r?ng d? li?u (Q10.13 signed)
    parameter ACC_W  = 56,    // Chi?u r?ng b? tích l?y. 56 bit ?? cho 16x16.
    parameter OUT_W  = 56     // Chi?u r?ng ??u ra. ??ng b? v?i ACC_W.
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start_a,      

    input  wire [COL_W-1:0] N_cols, // S? c?t (atom) c?n duy?t (ví d? 255 n?u 0-indexed)
    input  wire [ROW_W-1:0] M_rows, // S? l?n truy c?p b? nh? liên ti?p cho m?t c?t
                                    // (t?c là M_max / NUM_MAC)

    output reg  [ADDR_W-1:0] phi_addr, 
    input  wire [(NUM_MAC*DW)-1:0]   phi_data, // S?a: ?? r?ng bus phi_data ph? thu?c vào NUM_MAC

    output reg  [ROW_W-1:0]  r_addr, 
    input  wire [(NUM_MAC*DW)-1:0]   r_data,   // S?a: ?? r?ng bus r_data ph? thu?c vào NUM_MAC

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

    // S?a: Unpack d? li?u signed t? bus (NUM_MAC*DW)-bit
    wire signed [DW-1:0] p[0:NUM_MAC-1]; // M?ng các giá tr? p_i
    wire signed [DW-1:0] r[0:NUM_MAC-1]; // M?ng các giá tr? r_i
    
    genvar g; // S? d?ng generate block ?? unpack d? li?u m?t cách linh ho?t
    generate
        for (g = 0; g < NUM_MAC; g = g + 1) begin : unpack_loop
            assign p[g] = phi_data[g*DW +: DW];
            assign r[g] = r_data[g*DW +: DW];
        end
    endgenerate
    
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
                        // S?a: Phát ??a ch? hàng 0 ngay l?p t?c, dùng ROW_N
                        phi_addr <= (0 << ROW_N); 
                        r_addr   <= 0;
                    end
                end

                RUN_COL: begin
                    // 1. GIAI ?O?N PHÁT ??A CH? (Address Phase)
                    if (row_ptr < M_rows) begin
                        row_ptr  <= row_ptr + 1'b1;
                        // S?a: Tính toán ??a ch? phi_addr dùng ROW_N
                        phi_addr <= (col_ptr << ROW_N) + (row_ptr + 1'b1);
                        r_addr   <= row_ptr + 1'b1;
                        pipe_vld <= 1'b1;
                    end else begin
                        pipe_vld <= 1'b0; // ?ã phát h?t ??a ch? cho c?t này
                    end

                    // 2. GIAI ?O?N TÍCH L?Y (Data Phase - Tr? 1 nh?p)
                    // ? nh?p này, data c?a ??a ch? nh?p tr??c ?ã v? t?i bus
                    if (pipe_vld || (row_ptr > 0 && row_ptr <= M_rows)) begin
                        // S?a: Logic tích l?y s? d?ng các giá tr? ?ã unpack t? m?ng p và r
                        acc <= acc + 
                               ($signed(p[0]) * $signed(r[0])) +
                               ($signed(p[1]) * $signed(r[1])) +
                               ($signed(p[2]) * $signed(r[2])) +
                               ($signed(p[3]) * $signed(r[3]));
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
                        // S?a: Tính toán ??a ch? cho c?t ti?p theo dùng ROW_N
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


