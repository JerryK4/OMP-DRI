`timescale 1ns / 1ps

module qr_mgs_bram_test_wrapper #
(
    parameter DW = 24,
    parameter ADDR_W_PHI = 12,
    parameter ADDR_W_Q = 8,
    parameter DOT_W = 56
)
(
    input wire clk,
    input wire rst_n,
    input wire start_test,      // Kích ho?t toàn b? quy trình
    input wire [7:0] lambda_in, // N?i v?i h?ng s? 183
    input wire [4:0] current_i, // Vòng l?p test (th??ng là 0)
    
    output wire test_done,      // Báo hi?u hoàn thành c? Core và Update
    output wire [DW-1:0] out_alpha, // ?? soi giá tr? Alpha h?i t?
    output wire [DOT_W-1:0] out_u   // ?? soi n?ng l??ng u
);

    // --- Tín hi?u k?t n?i gi?a Wrapper và System Top ---
    wire [ADDR_W_PHI-1:0] phi_addr;
    wire [95:0]           phi_data;
    wire [7:0]            r_addr_a;
    wire                  r_we_a;
    wire [23:0]           r_din_a;
    wire [ADDR_W_Q-1:0]   q_addr_a, q_addr_b;
    wire                  q_we_a;
    wire [95:0]           q_din_a, q_dout_b;
    wire [3:0]            res_addr_a, res_addr_b;
    wire                  res_we_a;
    wire [95:0]           res_din_a, res_dout_b;
    wire                  mgs_done_all;

    // --- Tín hi?u cho quá trình n?p y vào res_mem (INIT phase) ---
    reg [3:0] init_cnt;
    reg       is_init;
    wire [3:0]  y_addr;
    wire [95:0] y_data;

    // --- ?i?u ph?i (Arbitration) Port A c?a Residual RAM ---
    // Lúc ??u n?p y, sau ?ó nh??ng cho kh?i Residual Update ghi r_new
    wire [3:0]  final_res_addr_a = is_init ? init_cnt : res_addr_a;
    wire        final_res_we_a   = is_init ? 1'b1     : res_we_a;
    wire [95:0] final_res_din_a  = is_init ? y_data   : res_din_a;

    /* ==========================================================
       1. KH?I T?O CÁC IP BRAM (N?i tr?c ti?p v?i các file .xci)
    ========================================================== */
    
    // BRAM ch?a ma tr?n Phi (N?p s?n .coe)
    phi_bram u_phi_mem (
        .clka(clk), .addra(phi_addr), .douta(phi_data)
    );

    // BRAM ch?a vector y (N?p s?n .coe)
    y_bram u_y_mem (
        .clka(clk), .addra(init_cnt), .douta(y_data)
    );

    // RAM th?ng d? (Residual) - Dùng Simple Dual Port
    // Port A: Ghi (INIT ho?c Update), Port B: ??c (Core ho?c Update)
    res_vec_ram u_res_mem (
        .clka(clk), .wea(final_res_we_a), .addra(final_res_addr_a), .dina(final_res_din_a),
        .clkb(clk), .addrb(res_addr_b), .doutb(res_dout_b)
    );

    // BRAM Q (Ma tr?n tr?c giao) - True Dual Port
    q_bram u_q_mem (
        .clka(clk), .wea(q_we_a), .addra(q_addr_a), .dina(q_din_a),
        .clkb(clk), .addrb(q_addr_b), .doutb(q_dout_b)
    );

    // BRAM R (H? s? ma tr?n tam giác)
    r_bram u_r_mem (
        .clka(clk), .wea(r_we_a), .addra(r_addr_a), .dina(r_din_a)
    );

    /* ==========================================================
       2. K?T N?I H? TH?NG T?NG (DUT)
    ========================================================== */
    reg mgs_start_trigger;
    qr_mgs_system_top u_system (
        .clk(clk), .rst_n(rst_n), .start_mgs(mgs_start_trigger),
        .lambda_i(lambda_in), .current_i(current_i),
        .phi_addr(phi_addr), .phi_data(phi_data),
        .r_addr_a(r_addr_a), .r_we_a(r_we_a), .r_din_a(r_din_a),
        .q_addr_a(q_addr_a), .q_we_a(q_we_a), .q_din_a(q_din_a),
        .q_addr_b(q_addr_b), .q_dout_b(q_dout_b),
        .res_addr_a(res_addr_a), .res_we_a(res_we_a), .res_din_a(res_din_a),
        .res_addr_b(res_addr_b), .res_dout_b(res_dout_b),
        .mgs_done_all(mgs_done_all)
    );

    assign out_alpha = u_system.u_res_upd.alpha_reg; // Peek Alpha ?? debug
    assign out_u     = u_system.u_mgs_core.u_mac.dot_result; // Peek u
    assign test_done = mgs_done_all;

    /* ==========================================================
       3. FSM ?I?U KHI?N N?P D? LI?U BAN ??U
    ========================================================== */
    reg [1:0] test_state;
    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_state <= 0; init_cnt <= 0; is_init <= 0; mgs_start_trigger <= 0;
        end else begin
            case (test_state)
                0: begin // IDLE
                    if (start_test) begin
                        test_state <= 1;
                        is_init <= 1;
                        init_cnt <= 0;
                    end
                end
                1: begin // INIT Phase: Copy y -> residual RAM
                    if (init_cnt == 15) begin
                        test_state <= 2;
                        is_init <= 0;
                    end else begin
                        init_cnt <= init_cnt + 1;
                    end
                end
                2: begin // START MGS
                    mgs_start_trigger <= 1'b1;
                    test_state <= 3;
                end
                3: begin // WAIT
                    mgs_start_trigger <= 1'b0;
                    if (mgs_done_all) test_state <= 0;
                end
            endcase
        end
    end

endmodule