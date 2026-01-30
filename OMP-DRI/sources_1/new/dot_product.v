module dot_product(
    input wire clk,
    input wire rst_n,
    input wire start_a,
    input wire [5:0] N, // Tham s? DRI
    input wire [2:0] M, // Tham s? DRI
    
    output reg [8:0] phi_addr, 
    input wire [95:0] phi_data,
    output reg [2:0] r_addr, 
    input wire [95:0] r_data,
    
    output reg [47:0] dot_result, 
    output reg [5:0] current_col_idx,
    output reg col_done, 
    output reg all_done  
);
    
    localparam IDLE      = 3'd0;
    localparam READ      = 3'd1;
    localparam ACCUM     = 3'd2;
    localparam NEXT_COL  = 3'd3;
    localparam WAIT_NEXT = 3'd4; // Tr?ng thái m?i ?? h? col_done
    localparam FINISH    = 3'd5;
    
    reg [2:0] state;
    reg [2:0] row_cnt; 
    reg [5:0] col_cnt; 
    reg signed [63:0] accumulator;
    
    wire signed [23:0] p0, p1, p2, p3, r0, r1, r2, r3;
    assign {p3, p2, p1, p0} = phi_data;
    assign {r3, r2, r1, r0} = r_data;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin    
            state <= IDLE;
            phi_addr <= 0; r_addr <= 0;
            accumulator <= 0;
            col_done <= 0; all_done <= 0;
            row_cnt <= 0; col_cnt <= 0;
            current_col_idx <= 0; dot_result <= 0;
        end else begin
            case(state) 
                IDLE: begin
                    all_done <= 0;
                    col_done <= 0;
                    if(start_a) begin    
                        state <= READ;
                        row_cnt <= 0;
                        col_cnt <= 0;
                        accumulator <= 0;
                        // G?i ??a ch? ??u tiên ngay t?i ?ây ?? làm s?ch pipeline
                        r_addr <= 0;
                        phi_addr <= 0; 
                    end
                end 
                
                READ: begin
                    col_done <= 0;
                    r_addr <= row_cnt;
                    phi_addr <= (col_cnt << 3) + row_cnt;
                    state <= ACCUM;
                end 
                
                ACCUM: begin
                    // Th?c hi?n c?ng d?n
                    accumulator <= accumulator + 
                                   ($signed(p0) * $signed(r0)) + 
                                   ($signed(p1) * $signed(r1)) + 
                                   ($signed(p2) * $signed(r2)) + 
                                   ($signed(p3) * $signed(r3));
                    
                    if (row_cnt == M) begin
                        state <= NEXT_COL;
                    end else begin
                        row_cnt <= row_cnt + 1;
                        r_addr <= row_cnt + 1;
                        phi_addr <= (col_cnt << 3) + (row_cnt + 1);
                        state <= ACCUM;
                    end
                end

                NEXT_COL: begin
                    dot_result <= accumulator[47:0]; 
                    current_col_idx <= col_cnt;
                    col_done <= 1; // B?t xung báo xong c?t
                    
                    if (col_cnt == N) begin
                        state <= FINISH;
                    end else begin
                        state <= WAIT_NEXT; // Nh?y sang tr?ng thái trung gian
                    end
                end
                
                WAIT_NEXT: begin
                    col_done <= 0; // H? xung col_done ngay l?p t?c
                    col_cnt <= col_cnt + 1;
                    row_cnt <= 0;
                    accumulator <= 0;
                    // Chu?n b? ??a ch? cho c?t ti?p theo
                    r_addr <= 0;
                    phi_addr <= ((col_cnt + 1) << 3);
                    state <= READ;
                end

                FINISH: begin
                    col_done <= 0;
                    all_done <= 1;
                    state <= IDLE;
                end 
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule