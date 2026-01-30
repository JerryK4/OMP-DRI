`timescale 1ns / 1ps

module finding_max(
    input wire clk,
    input wire rst_n,
    input wire start_search, 
    
    // Giao ti?p v?i Dot Product Engine
    input wire [47:0] dot_result,      
    input wire [5:0]  current_col_idx, 
    input wire        col_done,        
    input wire        all_done_in,     
    
    // Qu?n lý l?ch s? (Masking)
    input wire [4:0]   current_i,       
    input wire [111:0] lambda_history,  // 16 lambda x 7-bit
    
    // K?t qu? ??u ra
    output reg [5:0]  lambda,          
    output reg        finding_done     
);

    reg [47:0] max_val_reg;
    reg [5:0]  lambda_temp;
    reg        is_masked; 
    reg        first_valid_found; // C? báo hi?u ?ã tìm ???c c?t ??u tiên không b? khóa
    integer    k;

    // 1. Tính giá tr? tuy?t ??i (B?o toàn s? có d?u Q20.26)
    wire [47:0] abs_val = dot_result[47] ? (~dot_result + 1'b1) : dot_result;

    // 2. Logic tìm Max và Masking chu?n xác
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_val_reg <= 48'd0;
            lambda_temp <= 6'd0;
            lambda      <= 6'd0;
            finding_done <= 1'b0;
            first_valid_found <= 1'b0;
        end else begin
            if (start_search) begin
                // Reset tr?ng thái cho ??t tìm ki?m m?i trong vòng l?p OMP hi?n t?i
                max_val_reg <= 48'd0;
                lambda_temp <= 6'd0;
                finding_done <= 1'b0;
                first_valid_found <= 1'b0;
            end 
            else if (col_done) begin
                // --- B??C 1: KI?M TRA MASKING ---
                is_masked = 0; // Blocking assignment ?? có k?t qu? ngay cho if phía d??i
                for (k = 0; k < 16; k = k + 1) begin
                    if (k < current_i) begin
                        // Ki?m tra: Trùng index VÀ ô nh? history ?ó ph?i h?p l? (bit[6] == 0)
                        if (current_col_idx == lambda_history[k*7 +: 6] && lambda_history[k*7 + 6] == 1'b0)
                            is_masked = 1;
                    end
                end

                // --- B??C 2: SO SÁNH TÌM MAX ---
                if (!is_masked) begin
                    // N?u ?ây là c?t h?p l? (không b? mask) ??u tiên tìm th?y
                    if (!first_valid_found) begin
                        max_val_reg <= abs_val;
                        lambda_temp <= current_col_idx;
                        first_valid_found <= 1'b1;
                    end
                    // Ho?c n?u tìm th?y c?t có ?? t??ng quan th?c s? l?n h?n c?t Max c?
                    else if (abs_val > max_val_reg) begin
                        max_val_reg <= abs_val;
                        lambda_temp <= current_col_idx;
                    end
                end
            end 
            
            // --- B??C 3: CH?T K?T QU? ---
            if (all_done_in) begin
                lambda <= lambda_temp;
                finding_done <= 1'b1;
            end else begin
                finding_done <= 1'b0;
            end 
        end
    end

endmodule