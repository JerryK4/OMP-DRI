`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/21/2026 11:07:43 PM
// Design Name: 
// Module Name: top_test_block_a
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_test_block_a (
    input wire clk,
    input wire rst_n,
    input wire start_all,    
    
    // --- THÊM CÁC C?NG DRI ---
    input wire [5:0] N,      // Truy?n t? Testbench (15 ho?c 63)
    input wire [2:0] M,      // Truy?n t? Testbench (1 ho?c 7)
    
    output wire [5:0] lambda,
    output wire done_all
);

    // --- Tín hi?u k?t n?i BRAM ---
    wire [8:0]  phi_addr;
    wire [95:0] phi_data;
    wire [2:0]  init_cnt_wire; 
    wire [95:0] y_data;
    wire        r_we;
    wire [2:0]  r_addr_b; 
    wire [95:0] r_data_out;

    // --- Tín hi?u ?i?u khi?n FSM n?i b? ---
    reg [1:0] state;
    reg [2:0] init_cnt;
    reg start_block_a;
    
    localparam S_IDLE   = 2'd0;
    localparam S_INIT_R = 2'd1; // B??c copy y sang r
    localparam S_RUN_A  = 2'd2;
    localparam S_DONE   = 2'd3;

    // --- 1. G?i các IP BRAM th?t ---
    phi_bram your_phi (
        .clka(clk), .addra(phi_addr), .douta(phi_data), .wea(1'b0), .dina(96'b0)
    );

    y_bram your_y (
        .clka(clk), .addra(init_cnt), .douta(y_data)
    );

    r_bram your_r (
        .clka(clk), 
        .addra(init_cnt), .dina(y_data), .wea(r_we), // C?ng ghi s? d?ng init_cnt
        .clkb(clk), 
        .addrb(r_addr_b), .doutb(r_data_out)        // C?ng ??c cho Block A
    );

    // --- 2. G?i Block A Top (?ã c?p nh?t c?ng DRI) ---
    block_a_top uut_block_a (
        .clk(clk),
        .rst_n(rst_n),
        .start_a(start_block_a),
        .N(N),                  // Truy?n tham s? DRI xu?ng
        .M(M),                  // Truy?n tham s? DRI xu?ng
        .phi_addr(phi_addr),
        .phi_data(phi_data),
        .r_addr(r_addr_b),
        .r_data(r_data_out),     
        .lambda(lambda),
        .block_a_done(done_all)
    );

    // --- 3. Logic ?i?u ph?i (FSM) ---
    assign r_we = (state == S_INIT_R);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            init_cnt <= 0;
            start_block_a <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start_all) state <= S_INIT_R;
                    init_cnt <= 0;
                    start_block_a <= 0;
                end

                S_INIT_R: begin
                    // DRI: Thay vì d?ng ? 7, chúng ta d?ng ? M
                    // N?u M=1 (4x4), copy 2 dòng (0 và 1). N?u M=7 (8x8), copy 8 dòng.
                    if (init_cnt == M) begin
                        state <= S_RUN_A;
                        start_block_a <= 1; 
                    end else begin
                        init_cnt <= init_cnt + 1;
                    end
                end

                S_RUN_A: begin
                    start_block_a <= 0; 
                    if (done_all) state <= S_DONE;
                end

                S_DONE: begin
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule