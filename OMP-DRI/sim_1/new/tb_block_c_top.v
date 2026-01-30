`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 01/24/2026 03:52:49 PM
// Design Name:
// Module Name: tb_block_c_top
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
module tb_block_c_top();

// --- 1. Tín hi?u ?i?u khi?n ---
reg clk;
reg rst_n;
reg start_c;
reg [4:0] K_final;
reg [2:0] M_limit;

// Giao ti?p n?p Support Set (Gi? l?p k?t qu? t? Block A)
reg [5:0] lambda_in;
reg [3:0] lambda_idx;
reg       lambda_we;

// --- 2. Giao ti?p BRAM (Gi? l?p ph?n h?i) ---
wire [6:0]  q_addr;
reg  [95:0] q_rdata;
wire [2:0]  y_addr;
reg  [95:0] y_data;
wire [5:0]  u_addr;
reg  [95:0] u_rdata;

// --- 3. ??u ra ?nh khôi ph?c ---
wire [5:0]  pixel_addr;
wire [23:0] pixel_val;
wire        pixel_we;
wire        block_c_done;

// --- 4. K?t n?i Module Unit Under Test (UUT) ---
block_c_top uut (
    .clk(clk), .rst_n(rst_n), .start_c(start_c),
    .K_final(K_final), .M_limit(M_limit),
    .lambda_in(lambda_in), .lambda_idx(lambda_idx), .lambda_we(lambda_we),
    .q_addr(q_addr), .q_rdata(q_rdata),
    .y_addr(y_addr), .y_data(y_data),
    .u_addr(u_addr), .u_rdata(u_rdata),
    .pixel_addr(pixel_addr), .pixel_val(pixel_val), .pixel_we(pixel_we),
    .block_c_done(block_c_done)
);

// --- 5. T?o xung Clock 50MHz ---
always #10 clk = ~clk;

// --- 6. Gi? l?p d? li?u BRAM (D?a trên ví d? b=[9,16,8] và x=[1.5, 4, 2]) ---
always @(posedge clk) begin
    // Mock BRAM y: luôn tr? v? 1.0
    y_data <= {24'h0, 24'h0, 24'h0, 24'h002000}; 

    // Mock BRAM Q: gi? l?p ?? b = Q^T * y ra ?úng [9, 16, 8]
    // (Rút g?n: tr? v? giá tr? sao cho tích vô h??ng kh?p)
    q_rdata <= (q_addr == 0) ? {24'd0, 24'd0, 24'd0, 24'h002400} : // b0=9
               (q_addr == 8) ? {24'd0, 24'd0, 24'd0, 24'h004000} : // b1=16
               (q_addr == 16)? {24'd0, 24'd0, 24'd0, 24'h002000} : // b2=8
               96'd0;

    // Mock BRAM U: Gi?ng bài test Back-sub tr??c
    case (u_addr)
        6'd0: u_rdata <= {24'h0, 24'h0, 24'h0, 24'h004000}; // U[0,0]=2
        6'd4: u_rdata <= {24'h0, 24'h0, 24'h006000, 24'h002000}; // U[1,1]=3, U[0,1]=1
        6'd8: u_rdata <= {24'h0, 24'h008000, 24'h004000, 24'h002000}; // U[2,2]=4...
        default: u_rdata <= 96'h0;
    endcase
end

// --- 7. K?ch b?n ki?m tra ---
initial begin
    clk = 0; rst_n = 0; start_c = 0; K_final = 3; M_limit = 0; // Test nhanh v?i M c?c nh?
    lambda_in = 0; lambda_idx = 0; lambda_we = 0;
    #100 rst_n = 1; #40;

    // B??C 1: N?p Support Set (Gi? s? tìm ???c các pixel t?i v? trí 4, 10, 39)
    $display(">>> Step 1: Loading Support Set (Indices 4, 10, 39)");
    load_support(0, 4);
    load_support(1, 10);
    load_support(2, 39);
    #50;

    // B??C 2: B?t ??u tính toán khôi ph?c ?nh
    $display(">>> Step 2: Starting Image Estimation (Block C)");
    start_c = 1; #20; start_c = 0;

    // B??C 3: ??i xong và quan sát lu?ng pixel
    wait(block_c_done);
    #100;
    $display(">>> Block C Test Finished!");
    $stop;
end

// Task n?p support set
task load_support(input [3:0] idx, input [5:0] l_val);
begin
    lambda_idx = idx; lambda_in = l_val; lambda_we = 1; #20;
    lambda_we = 0; #20;
end
endtask

// --- 8. Monitor: Theo dõi các pixel khác 0 ?? ra ---
always @(posedge clk) begin
    if (pixel_we && pixel_val !== 0) begin
        $display("PIXEL FOUND | Addr: %d | Intensity: %h", pixel_addr, pixel_val);
    end
end
endmodule