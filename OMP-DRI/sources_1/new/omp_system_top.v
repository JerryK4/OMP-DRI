`timescale 1ns / 1ps

module omp_system_top (
    input wire clk,
    input wire rst_n,
    input wire start_system,    // Nút b?m b?t ??u khôi ph?c ?nh
    
    // Tham s? DRI (C?u hình t? bên ngoài)
    input wire [5:0] N_in,      // 63 cho ?nh 8x8
    input wire [2:0] M_in,      // 7 cho ?nh 8x8
    input wire [4:0] K_limit,   // 16 cho ?nh 8x8
    
    // ??u ra lu?ng Pixel ?? g?i lên PC ho?c Display
    output wire [5:0]  pixel_addr,
    output wire [23:0] pixel_val,
    output wire        pixel_we,
    output reg         done_all
);

    // --- 1. Khai báo các dây n?i tín hi?u ?i?u khi?n ---
    reg        start_core_ab;
    wire       done_core_ab;
    reg        start_block_c;
    wire       done_block_c;
    wire [4:0] final_iterations;
    
    // Dây n?i d? li?u Lambda "Online" t? AB sang C
    wire [5:0] lambda_bus;
    wire       lambda_we_wire;
    wire [4:0] current_i_bus;

    // --- 2. Dây n?i BRAM (Chia s? tài nguyên gi?a AB và C) ---
    wire [6:0]  q_addr_ext;
    wire [95:0] q_data_ext;
    wire [2:0]  y_addr_ext;
    wire [95:0] y_data_ext;
    wire [5:0]  u_addr_ext;
    wire [95:0] u_data_ext;

    // --- 3. Máy tr?ng thái (FSM) ?i?u khi?n Trung tâm ---
    reg [2:0] state;
    localparam S_IDLE    = 3'd0,
               S_RUN_AB  = 3'd1, // Giai ?o?n l?p tìm Lambda và ma tr?n U
               S_WAIT_AB = 3'd2,
               S_RUN_C   = 3'd3, // Giai ?o?n gi?i mã ?nh x_hat
               S_WAIT_C  = 3'd4,
               S_DONE    = 3'd5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            start_core_ab <= 0;
            start_block_c <= 0;
            done_all <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done_all <= 0;
                    if (start_system) state <= S_RUN_AB;
                end

                S_RUN_AB: begin
                    start_core_ab <= 1'b1; // Kích ho?t lõi OMP
                    state <= S_WAIT_AB;
                end

                S_WAIT_AB: begin
                    start_core_ab <= 1'b0; // H? xung start sau 1 chu k?
                    if (done_core_ab) state <= S_RUN_C;
                end

                S_RUN_C: begin
                    start_block_c <= 1'b1; // Kích ho?t kh?i khôi ph?c ?nh
                    state <= S_WAIT_C;
                end

                S_WAIT_C: begin
                    start_block_c <= 1'b0; // H? xung start sau 1 chu k?
                    if (done_block_c) state <= S_DONE;
                end

                S_DONE: begin
                    done_all <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // --- 4. K?t n?i OMP Core AB (Ph?n tìm ki?m và tr?c giao hóa) ---
    omp_core_ab inst_core_ab (
        .clk(clk),
        .rst_n(rst_n),
        .start_omp(start_core_ab),
        .N_in(N_in),
        .M_in(M_in),
        .K_limit(K_limit),
        
        // C?ng chia s? BRAM (Block C s? ??c t? ?ây khi done_omp = 1)
        .q_addr_ext(q_addr_ext), .q_data_ext(q_data_ext),
        .y_addr_ext(y_addr_ext), .y_data_ext(y_data_ext),
        .u_addr_ext(u_addr_ext), .u_data_ext(u_data_ext),

        // Xu?t tín hi?u ??ng b? sang Block C
        .lambda_out(lambda_bus),
        .lambda_we(lambda_we_wire),
        .current_i_out(current_i_bus),
        
        .final_i(final_iterations),
        .done_omp(done_core_ab)
    );

    // --- 5. K?t n?i Block C (Ph?n ??c l??ng và ánh x? ?nh) ---
    block_c_top inst_block_c (
        .clk(clk),
        .rst_n(rst_n),
        .start_c(start_block_c),
        .K_final(final_iterations + 1'b1), // Ví d?: final_i = 15 thì K = 16
        .M_limit(M_in),
        
        // Nh?n Support Set t? Core AB trong quá trình ch?y
        .lambda_in(lambda_bus),
        .lambda_idx(current_i_bus[3:0]),
        .lambda_we(lambda_we_wire),

        // ??c d? li?u BRAM thông qua các c?ng Proxy c?a Core AB
        .q_addr(q_addr_ext),   .q_rdata(q_data_ext),
        .y_addr(y_addr_ext),   .y_data(y_data_ext),
        .u_addr(u_addr_ext),   .u_rdata(u_data_ext),

        // ??u ra ?nh cu?i cùng
        .pixel_addr(pixel_addr),
        .pixel_val(pixel_val),
        .pixel_we(pixel_we),
        .block_c_done(done_block_c)
    );

endmodule