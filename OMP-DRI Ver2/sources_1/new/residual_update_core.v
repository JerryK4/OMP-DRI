`timescale 1ns / 1ps

module residual_update_core #
(
    parameter DW = 24,       // Q10.13
    parameter ROW_W = 4,      // 2^4 = 16 rows (cho M=64)
    parameter DOT_W = 56
)
(
    input wire clk,
    input wire rst_n,
    input wire start_update,
    
    // Interface v?i Q BRAM (??c c?t Qi v?a tính xong)
    output wire [ROW_W-1:0] q_addr,
    input  wire [95:0]      q_data,  // {q3, q2, q1, q0}

    // Interface v?i r BRAM (??c r_old, Ghi r_new)
    output reg  [ROW_W-1:0] r_addr,
    output reg              r_we,
    input  wire [95:0]      r_data_in, // r_old t? RAM
    output wire [95:0]      r_data_out, // r_new ghi vào RAM

    output reg              update_done
);

    // --- States ---
    localparam IDLE       = 3'd0,
               TRG_ALPHA  = 3'd1, // Kích ho?t MAC tính Alpha
               WAIT_ALPHA = 3'd2, // Ch? Alpha xong
               RD_RSUB    = 3'd3, // ??c r_old và Qi ?? tr?
               FINISH     = 3'd4;

    reg [2:0] state;
    reg [4:0] row_cnt;
    reg signed [23:0] alpha_reg;
    reg mac_start;
    wire mac_done;
    wire [DOT_W-1:0] mac_res;
    wire [ROW_W-1:0] mac_r_addr;

    // --- 1. Re-use Parallel Dot Product ?? tính Alpha ---
    dot_product_4mac #(.ROW_W(ROW_W)) u_mac_alpha (
        .clk(clk), .rst_n(rst_n), .start_a(mac_start),
        .M_rows(4'd15), .N_cols(8'd0),
        .phi_data(q_data),      // Vector Qi
        .r_data(r_data_in),     // Vector r_{i-1}
        .dot_result(mac_res),
        .all_done(mac_done),
        .r_addr(mac_r_addr)
    );

    // --- 2. Pipeline cho b??c Tr? (Subtraction) ---
    // C?n delay ??a ch? và tín hi?u ghi ?? kh?p v?i latency c?a Mul và Sub
    reg [ROW_W-1:0] addr_del [0:7];
    reg             we_del   [0:7];
    integer i;

    wire [95:0] mul_res, sub_res;
    
    // Nhân: Alpha * Qi
    mul_scalar_4set u_mul_alpha (
        .clk(clk), .rst_n(rst_n),
        .v_in(q_data), 
        .scalar(alpha_reg), 
        .shift(6'd13), // Q13 * Q13 -> Q13
        .v_out(mul_res)
    );

    // Tr?: r_old - (Alpha * Qi)
    // L?u ý: r_data_in c?n ???c delay ?? kh?p nh?p v?i mul_res
    reg [95:0] r_old_del [0:3]; 
    sub_4set u_sub_r (
        .clk(clk), .rst_n(rst_n),
        .a_vec(r_old_del[1]), // r_old ?ã delay
        .b_vec(mul_res), 
        .res_vec(sub_res)
    );

    assign r_data_out = sub_res;
    assign q_addr = (state == WAIT_ALPHA || state == TRG_ALPHA) ? mac_r_addr : row_cnt[3:0];

    // --- 3. FSM Control ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; update_done <= 0; mac_start <= 0;
            alpha_reg <= 0; row_cnt <= 0; r_we <= 0;
            for(i=0; i<8; i=i+1) begin addr_del[i] <= 0; we_del[i] <= 0; end
            for(i=0; i<4; i=i+1) r_old_del[i] <= 0;
        end else begin
            mac_start <= 0; r_we <= 0; update_done <= 0;

            // Shift registers cho Pipeline
            addr_del[0] <= row_cnt[3:0];
            we_del[0]   <= (state == RD_RSUB) && (row_cnt <= 15);
            for(i=1; i<8; i=i+1) begin addr_del[i] <= addr_del[i-1]; we_del[i] <= we_del[i-1]; end
            
            r_old_del[0] <= r_data_in;
            for(i=1; i<4; i=i+1) r_old_del[i] <= r_old_del[i-1];

            case (state)
                IDLE: begin
                    if (start_update) state <= TRG_ALPHA;
                end

                TRG_ALPHA: begin
                    mac_start <= 1;
                    state <= WAIT_ALPHA;
                end

                WAIT_ALPHA: begin
                    // ??a ch? RAM r và Q ???c ?i?u khi?n b?i module MAC
                    r_addr <= mac_r_addr; 
                    if (mac_done) begin
                        alpha_reg <= mac_res[13 +: 24]; // Ch?t Alpha (Q13)
                        state <= RD_RSUB;
                        row_cnt <= 0;
                    end
                end

                RD_RSUB: begin
                    r_addr <= row_cnt[3:0];
                    // Pipeline s? t? x? lý vi?c tr? và ghi l?i
                    r_we <= we_del[5]; // Latency: RAM(1) + Mul(2) + Sub(2) = ~5 nh?p
                    r_addr <= addr_del[5]; 
                    
                    if (row_cnt >= 22) begin // Ch? pipeline tr?ng
                        update_done <= 1;
                        state <= IDLE;
                    end else begin
                        row_cnt <= row_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule