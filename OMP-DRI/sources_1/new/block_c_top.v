`timescale 1ns / 1ps

module block_c_top (
    input wire clk,
    input wire rst_n,
    input wire start_c,
    input wire [4:0] K_final,      // K th?c t? (ví d? 16 cho 8x8)
    input wire [2:0] M_limit,      
    
    // Nh?n d? li?u t? Core AB
    input wire [5:0] lambda_in,    
    input wire [3:0] lambda_idx,   
    input wire       lambda_we,    

    // Giao ti?p BRAM (N?i ra Top System)
    output wire [6:0] q_addr,
    input  wire [95:0] q_rdata,
    output wire [2:0] y_addr,
    input  wire [95:0] y_data,
    output wire [5:0] u_addr,
    input  wire [95:0] u_rdata,

    // ??U RA ?NH: Lu?ng 64 pixel khôi ph?c
    output reg [5:0]  pixel_addr,  
    output reg [23:0] pixel_val,   
    output reg        pixel_we,    
    output reg        block_c_done
);

    // --- 1. B? nh? n?i b? (S? d?ng signed cho x_coeff_buf) ---
    reg [6:0]         support_set  [0:15]; 
    reg signed [23:0] x_coeff_buf  [0:15]; 
    reg [63:0]        image_bitmap;        

    // --- 2. Dây n?i tín hi?u n?i b? ---
    wire [3:0]  b_idx_wire;
    wire [23:0] b_val_wire;
    wire        b_we_wire;
    wire        done_b_vec;
    
    wire [3:0]  x_idx_wire;
    wire [23:0] x_val_wire;
    wire        x_we_wire;
    wire        done_bsub;

    reg start_bsub;
    integer n;

    // Máy tr?ng thái
    localparam S_IDLE       = 3'd0,
               S_CALC_B     = 3'd1, 
               S_BACK_SUB   = 3'd2, 
               S_MAP_WAIT   = 3'd3, 
               S_MAP_IMAGE  = 3'd4, 
               S_DONE       = 3'd5;

    reg [2:0] state;
    reg [5:0] map_cnt;

    // --- 3. Kh?i t?o Sub-modules (Dùng l?i ?úng code b?n ?ã test thành công) ---
    calc_b_vector inst_calc_b (
        .clk(clk), .rst_n(rst_n), .start_calc_b(start_c),
        .K_final(K_final), .M_limit(M_limit),
        .q_addr(q_addr), .q_rdata(q_rdata),
        .y_addr(y_addr), .y_data(y_data),
        .b_idx(b_idx_wire), .b_val(b_val_wire), .b_we(b_we_wire),
        .done_b_vec(done_b_vec)
    );

    back_substitution inst_bsub (
        .clk(clk), .rst_n(rst_n), .start_bsub(start_bsub),
        .K_final(K_final),
        .b_idx_in(b_idx_wire), .b_val_in(b_val_wire), .b_we_in(b_we_wire),
        .u_addr(u_addr), .u_rdata(u_rdata),
        .x_idx(x_idx_wire), .x_val(x_val_wire), .x_we(x_we_wire),
        .done_bsub(done_bsub)
    );

    // --- 4. C?p nh?t Support Set (L?u Lambda khi Block A ch?y) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            image_bitmap <= 64'd0;
            // Kh?i t?o support_set v? giá tr? 64 ?? tránh l?i 'x' và trùng pixel 0
            for (n = 0; n < 16; n = n + 1) support_set[n] <= 7'd64; 
        end else if (lambda_we) begin
            support_set[lambda_idx] <= {1'b0, lambda_in};
            image_bitmap[lambda_in] <= 1'b1; 
        end
    end

    // --- 5. FSM ?i?u ph?i khôi ph?c ?nh ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; block_c_done <= 0; start_bsub <= 0;
            pixel_we <= 0; map_cnt <= 0; pixel_addr <= 0; pixel_val <= 0;
            for (n = 0; n < 16; n = n + 1) x_coeff_buf[n] <= 24'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    block_c_done <= 0;
                    pixel_we <= 0;
                    if (start_c) begin 
                        state <= S_CALC_B;
                        for (n = 0; n < 16; n = n + 1) x_coeff_buf[n] <= 24'd0;
                    end
                end

                S_CALC_B: begin
                    if (done_b_vec) begin
                        state <= S_BACK_SUB;
                        start_bsub <= 1'b1; 
                    end
                end

                S_BACK_SUB: begin
                    start_bsub <= 1'b0;
                    // Thu th?p các h? s? x_hat ?? v? t? module bsub
                    if (x_we_wire) x_coeff_buf[x_idx_wire] <= x_val_wire;
                    
                    if (done_bsub) state <= S_MAP_WAIT;
                end

                S_MAP_WAIT: begin
                    // Nh?p ngh? 1 cycle ?? ??m b?o x_coeff_buf[0] ?ã ???c ghi xong
                    state <= S_MAP_IMAGE;
                    map_cnt <= 0;
                end

                S_MAP_IMAGE: begin
                    pixel_we   <= 1'b1;
                    pixel_addr <= map_cnt;
                    
                    // N?u bit t?i map_cnt là 1 -> Pixel này là thành ph?n th?a
                    if (image_bitmap[map_cnt]) begin
                        pixel_val <= x_coeff_buf[get_idx(map_cnt)];
                    end else begin
                        pixel_val <= 24'd0;
                    end

                    if (map_cnt == 6'd63) begin
                        state <= S_DONE;
                    end else begin
                        map_cnt <= map_cnt + 1'b1;
                    end
                end

                S_DONE: begin
                    pixel_we <= 0;
                    block_c_done <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

    // --- 6. Hàm tìm th? t? c?a Lambda (H? tr? 7-bit) ---
    function [3:0] get_idx(input [5:0] p_addr);
        integer k;
        begin
            get_idx = 4'd0;
            for (k = 0; k < 16; k = k + 1) begin
                // Ki?m tra bit th? 7 (support_set[6]) ?? ??m b?o index ?ó h?p l?
                if (support_set[k][5:0] == p_addr && support_set[k][6] == 1'b0) 
                    get_idx = k[3:0];
            end
        end
    endfunction

endmodule