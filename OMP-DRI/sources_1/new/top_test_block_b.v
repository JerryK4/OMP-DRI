`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 08:59:47 PM
// Design Name: 
// Module Name: top_test_block_b
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



module top_test_block_b (
    input wire clk,
    input wire rst_n,
    input wire start_b,
    input wire [5:0] lambda,
    input wire [4:0] current_i,
    input wire [2:0] M_limit,
    output wire done_b
);
    // --- 1. Các dây n?i BRAM (Phi, Q, R) ---
    wire [8:0]  phi_addr;
    wire [95:0] phi_data;
    wire [6:0]  q_addr;
    wire [95:0] q_wdata, q_rdata;
    wire        q_we;
    wire [2:0]  r_addr;
    wire [95:0] r_wdata, r_rdata;
    wire        r_we;

    // --- 2. Các dây n?i BRAM U (M?i b? sung) ---
    wire [5:0]  u_addr;
    wire [95:0] u_wdata, u_rdata;
    wire        u_we;

    // --- 3. G?i các IP BRAM th?t ---
    phi_bram b_phi (
        .clka(clk), .addra(phi_addr), .douta(phi_data), .wea(1'b0), .dina(96'b0)
    );
    
    q_bram b_q (
        .clka(clk), .addra(q_addr), .dina(q_wdata), .wea(q_we),
        .clkb(clk), .addrb(q_addr), .doutb(q_rdata)
    );

    r_bram b_r (
        .clka(clk), .addra(r_addr), .dina(r_wdata), .wea(r_we),
        .clkb(clk), .addrb(r_addr), .doutb(r_rdata)
    );

    // IP BRAM U (M?i b? sung)
    u_bram b_u (
        .clka(clk), .addra(u_addr), .dina(u_wdata), .wea(u_we),
        .clkb(clk), .addrb(u_addr), .doutb(u_rdata) // C?ng B ?? quan sát k?t qu?
    );

    // --- 4. G?i module Block B (?ã c?p nh?t c?ng n?i U) ---
    block_b_mgs uut_b (
        .clk(clk),
        .rst_n(rst_n),
        .start_b(start_b),
        .lambda(lambda),
        .current_i(current_i),
        .M_limit(M_limit),
        
        // Giao ti?p Phi
        .phi_addr(phi_addr),
        .phi_data(phi_data),
        
        // Giao ti?p Q
        .q_addr(q_addr),
        .q_wdata(q_wdata),
        .q_we(q_we),
        .q_rdata(q_rdata),
        
        // Giao ti?p R
        .r_addr(r_addr),
        .r_wdata(r_wdata),
        .r_we(r_we),
        .r_rdata(r_rdata),

        // Giao ti?p U (M?i n?i dây vào ?ây)
        .u_addr(u_addr),
        .u_wdata(u_wdata),
        .u_we(u_we),
        
        .done_b(done_b)
    );

endmodule
