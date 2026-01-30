`timescale 1ns / 1ps

module omp_core_ab (
    input wire clk,
    input wire rst_n,
    input wire start_omp,
    input wire [5:0] N_in,
    input wire [2:0] M_in,
    input wire [4:0] K_limit,
    
    // --- GIAO TI?P BRAM CHO BLOCK C (N?i ra Testbench/Top) ---
    input  wire [6:0]  q_addr_ext,
    output wire [95:0] q_data_ext,
    input  wire [2:0]  y_addr_ext,
    output wire [95:0] y_data_ext,
    input  wire [5:0]  u_addr_ext,
    output wire [95:0] u_data_ext,

    // --- TÍN HI?U ??NG B? SANG BLOCK C ---
    output wire [5:0]  lambda_out,
    output wire        lambda_we,
    output wire [4:0]  current_i_out,
    output reg  [4:0]  final_i,
    output reg         done_omp
);

    // --- 1. Khai báo các dây n?i (Wires) ---
    reg [3:0] state;
    reg [4:0] current_i;
    reg [2:0] init_cnt;
    reg [2:0] init_cnt_d1;      // Delay ??a ch? ?? kh?p d? li?u BRAM Y
    reg       start_a, start_b;
    reg [6:0] lambda_history [0:15]; 
    
    wire [111:0] lambda_history_packed;
    wire         done_a, done_b;
    wire [5:0]   lambda_bus;
    
    // Dây n?i ??a ch?/d? li?u BRAM n?i b?
    wire [8:0]   phi_addr_a, phi_addr_b, phi_addr_final;
    wire [95:0]  phi_data;
    wire [6:0]   q_addr_b, q_addr_final;
    wire [95:0]  q_wdata_b, q_rdata;
    wire         q_we_b;
    wire [2:0]   r_addr_a, r_addr_b, r_addr_final;
    wire [95:0]  r_wdata_b, r_rdata, y_data;
    wire         r_we_b, r_we_final;
    wire [5:0]   u_addr_b, u_addr_final;
    wire [95:0]  u_wdata_b, u_rdata;
    wire         u_we_b;

    integer m;
    genvar k;

    // ?óng gói l?ch s? Lambda (Masking)
    generate
        for (k = 0; k < 16; k = k + 1) begin : pack_history
            assign lambda_history_packed[k*7 +: 7] = lambda_history[k];
        end
    endgenerate

    // --- 2. Kh?i t?o các IP BRAM n?i b? ---
    phi_bram mem_phi (.clka(clk), .addra(phi_addr_final), .douta(phi_data), .wea(1'b0), .dina(96'b0));
    
    assign q_addr_final = (done_omp) ? q_addr_ext : q_addr_b;
    q_bram mem_q (.clka(clk), .addra(q_addr_final), .dina(q_wdata_b), .wea(q_we_b), .clkb(clk), .addrb(q_addr_final), .doutb(q_rdata));
    assign q_data_ext = q_rdata;

    assign r_addr_final = (state == 4'd2) ? init_cnt_d1 : ((state == 4'd3 || state == 4'd4) ? r_addr_a : r_addr_b);
    assign r_we_final   = (state == 4'd2) ? (init_cnt_d1 != init_cnt || (init_cnt == M_in)) : r_we_b;
    r_bram mem_r (.clka(clk), .addra(r_addr_final), .dina((state == 4'd2) ? y_data : r_wdata_b), .wea(r_we_final), .clkb(clk), .addrb(r_addr_final), .doutb(r_rdata));

    y_bram mem_y (.clka(clk), .addra((done_omp) ? y_addr_ext : init_cnt), .douta(y_data));
    assign y_data_ext = y_data;

    assign u_addr_final = (done_omp) ? u_addr_ext : u_addr_b;
    u_bram mem_u (.clka(clk), .addra(u_addr_final), .dina(u_wdata_b), .wea(done_omp ? 1'b0 : u_we_b), .clkb(clk), .addrb(u_addr_final), .doutb(u_rdata));
    assign u_data_ext = u_rdata;

    // --- 3. Logic ?i?u ph?i ---
    assign phi_addr_final = (state == 4'd3 || state == 4'd4) ? phi_addr_a : phi_addr_b;
    assign lambda_out    = lambda_bus;
    assign lambda_we     = done_a;
    assign current_i_out = current_i;

    // --- 4. Máy tr?ng thái (FSM) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; current_i <= 0; init_cnt <= 0; init_cnt_d1 <= 0;
            start_a <= 0; start_b <= 0; done_omp <= 0; final_i <= 0;
            for (m=0; m<16; m=m+1) lambda_history[m] <= 7'd64;
        end else begin
            init_cnt_d1 <= init_cnt;
            case (state)
                4'd0: begin // IDLE
                    done_omp <= 0;
                    if (start_omp) state <= 4'd1;
                    current_i <= 0; init_cnt <= 0;
                end

                4'd1: state <= 4'd2; // Nh?p ??m ??i BRAM Y tr? data

                4'd2: begin // INIT: R = y (N?p Residual ban ??u)
                    if (init_cnt_d1 == M_in && init_cnt == M_in) begin
                        state <= 4'd3; init_cnt <= 0;
                    end else if (init_cnt < M_in) begin
                        init_cnt <= init_cnt + 1;
                    end
                end

                4'd3: begin start_a <= 1'b1; state <= 4'd4; end
                4'd4: begin start_a <= 1'b0; if (done_a) state <= 4'd5; end

                4'd5: begin // LATCH LAMBDA: Ghi vào l?ch s? ?? Masking
                    lambda_history[current_i] <= {1'b0, lambda_bus}; 
                    state <= 4'd6;
                end

                4'd6: begin start_b <= 1'b1; state <= 4'd7; end
                4'd7: begin start_b <= 1'b0; if (done_b) state <= 4'd8; end

                4'd8: begin // LOOP INCREMENT
                    if (current_i == K_limit - 1'b1) state <= 4'd9;
                    else begin
                        current_i <= current_i + 1'b1;
                        state <= 4'd3;
                    end
                end

                4'd9: begin // DONE
                    final_i <= current_i;
                    done_omp <= 1'b1;
                    state <= 4'd0;
                end
            endcase
        end
    end

    // --- 5. K?t n?i Block A & Block B ---
    block_a_top i_block_a (
        .clk(clk), .rst_n(rst_n), .start_a(start_a), .N(N_in), .M(M_in),
        .current_i(current_i), .lambda_history(lambda_history_packed),
        .phi_addr(phi_addr_a), .phi_data(phi_data),
        .r_addr(r_addr_a), .r_data(r_rdata),
        .lambda(lambda_bus), .block_a_done(done_a)
    );

    block_b_mgs i_block_b (
        .clk(clk), .rst_n(rst_n), .start_b(start_b), .lambda(lambda_bus), .current_i(current_i), .M_limit(M_in),
        .phi_addr(phi_addr_b), .phi_data(phi_data),
        .q_addr(q_addr_b), .q_wdata(q_wdata_b), .q_we(q_we_b), .q_rdata(q_rdata),
        .r_addr(r_addr_b), .r_wdata(r_wdata_b), .r_we(r_we_b), .r_rdata(r_rdata),
        .u_addr(u_addr_b), .u_wdata(u_wdata_b), .u_we(u_we_b),
        .done_b(done_b)
    );

endmodule