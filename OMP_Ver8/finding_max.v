//`timescale 1ns / 1ps

//module finding_max #
//(
//    parameter DOT_W        = 56,
//    parameter COL_W        = 8,
//    parameter MAX_I        = 16,
//    parameter HIST_W       = 9
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start_search,      
    
//    input  wire signed [DOT_W-1:0] dot_result,      
//    input  wire [COL_W-1:0]        current_col_idx, 
//    input  wire                    col_done,        
//    input  wire                    all_done_in,     
    
//    input  wire [$clog2(MAX_I):0]  current_i,       
//    input  wire [MAX_I*HIST_W-1:0] lambda_history,  
    
//    output reg  [COL_W-1:0]        lambda,          
//    output reg                     finding_done     
//);

//    reg [DOT_W-1:0] max_val_reg;    
//    reg [COL_W-1:0] lambda_temp;
//    reg             first_valid_found;

//    /* ==========================================================
//       FUNCTION: Ki?m tra Mask (Tránh t?o thanh ghi th?a)
//    ========================================================== */
//    function is_masked;
//        input [COL_W-1:0] idx;
//        input [$clog2(MAX_I):0] curr_i;
//        input [MAX_I*HIST_W-1:0] history;
//        integer i;
//        begin
//            is_masked = 1'b0;
//            for (i = 0; i < MAX_I; i = i + 1) begin
//                if (i < curr_i) begin
//                    if ((idx == history[i*HIST_W +: COL_W]) && 
//                        (history[i*HIST_W + COL_W] == 1'b1)) begin
//                        is_masked = 1'b1;
//                    end
//                end
//            end
//        end
//    endfunction

//    /* ===============================
//       Absolute value (Tr? tuy?t ??i)
//    =============================== */
//    wire [DOT_W-1:0] abs_val;
//    assign abs_val = (dot_result[DOT_W-1]) ? (~dot_result + 1'b1) : dot_result;

//    /* ===============================
//       Max Search Logic
//    =============================== */
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            max_val_reg       <= 0;
//            lambda_temp       <= 0;
//            lambda            <= 0;
//            finding_done      <= 1'b0;
//            first_valid_found <= 1'b0;
//        end else begin
            
//            if (start_search) begin
//                max_val_reg       <= 0;
//                lambda_temp       <= 0;
//                finding_done      <= 1'b0;
//                first_valid_found <= 1'b0;
//            end 
//            else if (col_done) begin
//                // G?i function ?? ki?m tra mask (Logic t? h?p thu?n túy)
//                if (!is_masked(current_col_idx, current_i, lambda_history)) begin
//                    if (!first_valid_found) begin
//                        max_val_reg       <= abs_val;
//                        lambda_temp       <= current_col_idx;
//                        first_valid_found <= 1'b1;
//                    end
//                    else if (abs_val > max_val_reg) begin
//                        max_val_reg       <= abs_val;
//                        lambda_temp       <= current_col_idx;
//                    end
//                end
//            end

//            if (all_done_in) begin
//                lambda       <= lambda_temp;
//                finding_done <= 1'b1;
//            end else begin
//                finding_done <= 1'b0;
//            end
//        end
//    end

//endmodule


`timescale 1ns / 1ps

module finding_max #
(
    // --- S?a: Các tham s? cho c?u hình 16x16 ---
    parameter DOT_W  = 56,    // ?? r?ng k?t qu? tích vô h??ng (kh?p v?i module dot_product)
    parameter COL_W  = 8,     // ?? r?ng ch? s? c?t cho 16x16 (N=256 -> 8-bit)
    parameter MAX_I  = 16,    // ?? th?a t?i ?a K cho ?nh 16x16
    
    // --- S?a: Tham s? l?ch s? (Index + Valid bit) ---
    parameter HIST_BIT_VLD = 1,                 // 1 bit dùng làm c? Valid trong history
    parameter HIST_W       = COL_W + HIST_BIT_VLD, // S?a: T? ??ng tính HIST_W (8+1=9 bit)
    
    // --- S?a: Tính toán ?? r?ng bit cho b? ??m Iteration ---
    parameter I_W          = $clog2(MAX_I) + 1  // S?a: ?? r?ng bit cho current_i
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start_search,      
    
    input  wire signed [DOT_W-1:0] dot_result,      
    input  wire [COL_W-1:0]        current_col_idx, 
    input  wire                    col_done,        
    input  wire                    all_done_in,     
    
    input  wire [I_W-1:0]          current_i,       // S?a: Dùng I_W thay cho bi?u th?c hardcode
    input  wire [MAX_I*HIST_W-1:0] lambda_history,  
    
    output reg  [COL_W-1:0]        lambda,          
    output reg                     finding_done     
);

    // --- S?a: Các thanh ghi n?i b? dùng tham s? ---
    reg [DOT_W-1:0] max_val_reg;    
    reg [COL_W-1:0] lambda_temp;
    reg             first_valid_found;

    /* ==========================================================
       FUNCTION: Ki?m tra Mask (Gi? nguyên logic g?c c?a b?n)
    ========================================================== */
    function is_masked;
        input [COL_W-1:0] idx;
        input [I_W-1:0]   curr_i; // S?a: Dùng I_W
        input [MAX_I*HIST_W-1:0] history;
        integer i;
        begin
            is_masked = 1'b0;
            for (i = 0; i < MAX_I; i = i + 1) begin
                if (i < curr_i) begin
                    // S?a: S? d?ng COL_W làm offset ?? ki?m tra bit Valid ? v? trí th? 9 (index 8)
                    if ((idx == history[i*HIST_W +: COL_W]) && 
                        (history[i*HIST_W + COL_W] == 1'b1)) begin
                        is_masked = 1'b1;
                    end
                end
            end
        end
    endfunction

    /* ===============================
       Absolute value (Tr? tuy?t ??i)
    =============================== */
    wire [DOT_W-1:0] abs_val;
    // S?a: Dùng DOT_W ?? xác ??nh bit d?u
    assign abs_val = (dot_result[DOT_W-1]) ? (~dot_result + 1'b1) : dot_result;

    /* ===============================
       Max Search Logic (Tuy?t ??i gi? nguyên logic FSM)
    =============================== */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_val_reg       <= 0;
            lambda_temp       <= 0;
            lambda            <= 0;
            finding_done      <= 1'b0;
            first_valid_found <= 1'b0;
        end else begin
            
            if (start_search) begin
                max_val_reg       <= 0;
                lambda_temp       <= 0;
                finding_done      <= 1'b0;
                first_valid_found <= 1'b0;
            end 
            else if (col_done) begin
                // S?a: G?i function v?i các tham s? ?ã c?p nh?t
                if (!is_masked(current_col_idx, current_i, lambda_history)) begin
                    if (!first_valid_found) begin
                        max_val_reg       <= abs_val;
                        lambda_temp       <= current_col_idx;
                        first_valid_found <= 1'b1;
                    end
                    else if (abs_val > max_val_reg) begin
                        max_val_reg       <= abs_val;
                        lambda_temp       <= current_col_idx;
                    end
                end
            end

            if (all_done_in) begin
                lambda       <= lambda_temp;
                finding_done <= 1'b1;
            end else begin
                finding_done <= 1'b0;
            end
        end
    end

endmodule