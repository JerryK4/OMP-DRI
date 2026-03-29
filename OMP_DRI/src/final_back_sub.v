`timescale 1ns / 1ps

module final_back_sub #
(
    // --- Tham s? h? th?ng ---
    parameter DW         = 24,      // ?? r?ng d? li?u g?c (Q11.13)
    parameter K_MAX      = 16,      // S? nguyên t? t?i ?a (K)
    parameter VW         = 48,      // ?? r?ng m?i ph?n t? vector v (Qxx.26)
    
    // --- Tham s? ??nh d?ng Q-format (Tuy?t ??i không ??i) ---
    parameter FW_DATA    = 13,      // S? bit l? c?a d? li?u (13 bit)
    parameter FW_ISR     = 22,      // S? bit l? c?a k?t qu? ISR (22 bit)

    // --- Tham s? ??a ch? ---
    parameter ADDR_W_R   = 8,       // log2(16*16) = 8 bit ??a ch? R-BRAM
    parameter K_W        = 5        // ?? r?ng bit ch? s?: clog2(K_MAX) + 1 
                                    // (Dùng 5-bit signed ?? ch?a giá tr? +15 an toàn)
)
(
    input wire clk,
    input wire rst_n,
    input wire start_bs,
    
    // ?? r?ng bus v_in_flat t? ??ng tính: 16 * 48 = 768 bit
    input wire [(K_MAX*VW)-1:0] v_in_flat,
    
    // Giao ti?p r_bram
    output reg  [ADDR_W_R-1:0] r_addr,
    input  wire [DW-1:0]       r_dout,

    // Output Outstream
    output reg [DW-1:0]        x_hat_val,
    output reg [K_W-2:0]       x_hat_idx, // T??ng ???ng [3:0] cho 16x16
    output reg                 x_hat_valid,
    output reg                 bs_done
);

    // --- Các h?ng s? n?i b? tính toán t? Parameter ---
    localparam K_STRIDE  = $clog2(K_MAX);          // log2(16) = 4
    localparam signed [K_W-1:0] START_IDX = K_MAX - 1; // 15

    localparam IDLE      = 3'd0,
               FETCH_R   = 3'd1, 
               WAIT_RAM  = 3'd2, 
               CALC      = 3'd3, 
               OUT_DATA  = 3'd4;

    reg [2:0] state;
    reg signed [K_W-1:0]  i_idx, j_idx; // S? d?ng K_W (5 bit) ?? ??m b?o +15 là s? d??ng
    reg signed [VW-1:0]   sum_reg;      // Gi? nguyên 48-bit
    reg signed [DW-1:0]   x_hat_mem [0:K_MAX-1]; 
    
    // Unpack vector v_in linh ho?t theo K_MAX
    wire signed [VW-1:0] v_in [0:K_MAX-1];
    genvar k;
    generate
        for (k = 0; k < K_MAX; k = k + 1) begin : unpack_v
            assign v_in[k] = $signed(v_in_flat[k*VW +: VW]);
        end
    endgenerate

    integer m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; bs_done <= 0; x_hat_valid <= 0;
            r_addr <= 0; sum_reg <= 0; i_idx <= 0; j_idx <= 0;
            x_hat_val <= 0; x_hat_idx <= 0;
            for (m=0; m<K_MAX; m=m+1) x_hat_mem[m] <= {DW{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    bs_done <= 1'b0; x_hat_valid <= 1'b0;
                    if (start_bs) begin
                        state <= FETCH_R;
                        i_idx <= START_IDX; // Kh?i t?o 15
                        j_idx <= START_IDX; 
                        sum_reg <= {VW{1'b0}};
                    end
                end

                FETCH_R: begin
                    // r_addr = (j * 16) + i. S? d?ng K_STRIDE (4) thay cho s? 4 c?ng.
                    r_addr <= (j_idx << K_STRIDE) + i_idx;
                    state  <= WAIT_RAM;
                end

                WAIT_RAM: state <= CALC;

                CALC: begin
                    if (j_idx > i_idx) begin
                        // sum += R[i,j] * x[j]. S? d?ng FW_DATA (13) thay cho s? 13 c?ng.
                        sum_reg <= sum_reg + (($signed(r_dout) * $signed(x_hat_mem[j_idx])) >>> FW_DATA);
                        j_idx   <= j_idx - 1;
                        state   <= FETCH_R;
                    end else begin
                        // x[i] = (v[i] - sum) * ISR[i]
                        // Slicing sum_reg[36:0] ???c tính toán t? (DW + FW_DATA - 1) = 24 + 13 - 1 = 36
                        x_hat_mem[i_idx] <= (($signed(v_in[i_idx] >>> FW_DATA) - $signed(sum_reg[DW+FW_DATA-1 : 0])) * $signed(r_dout)) >>> FW_ISR;
                        
                        if (i_idx == 0) begin
                            state <= OUT_DATA;
                            i_idx <= 0;
                        end else begin
                            i_idx <= i_idx - 1;
                            j_idx <= START_IDX;
                            sum_reg <= {VW{1'b0}};
                            state <= FETCH_R;
                        end
                    end
                end

                OUT_DATA: begin
                    x_hat_valid <= 1'b1;
                    x_hat_idx   <= i_idx[K_W-2:0]; // L?y ph?n index (4 bit cho 16x16)
                    x_hat_val   <= x_hat_mem[i_idx];
                    if (i_idx == START_IDX) begin
                        bs_done <= 1'b1;
                        state <= IDLE;
                    end else i_idx <= i_idx + 1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule