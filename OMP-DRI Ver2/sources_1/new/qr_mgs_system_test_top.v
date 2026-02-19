//`timescale 1ns / 1ps

//module qr_mgs_system_test_top #
//(
//    parameter DW = 24,
//    parameter ADDR_W_PHI = 12,
//    parameter ADDR_W_Q = 8,
//    parameter DOT_W = 56
//)
//(
//    input wire clk,
//    input wire rst_n,
//    input wire start_core,      // Xung b?t ??u t? nút b?m ho?c switch
//    input wire [7:0] lambda_in, // N?i v?i h?ng s? 183 (0xb7)
//    input wire [4:0] current_i, // Vòng l?p hi?n t?i
//    input wire [3:0] M_rows,    // S? hàng (15 cho 16x16)

//    // Output ?? quan sát b?ng ILA/Testbench
//    output wire core_done,
//    output wire [DOT_W-1:0] debug_u_val,     // Giá tr? n?ng l??ng u
//    output wire [DW-1:0]    debug_alpha_val, // Giá tr? Alpha t??ng quan
//    output wire [DW-1:0]    debug_rii_val    // Giá tr? Rii (1/sqrt(u))
//);

//    // --- Signals k?t n?i n?i b? ---
//    wire [ADDR_W_PHI-1:0] phi_addr;
//    wire [95:0]           phi_data;

//    wire [7:0]            r_addr_a;
//    wire                  r_we_a;
//    wire [23:0]           r_din_a;

//    wire [ADDR_W_Q-1:0]   q_addr_a, q_addr_b;
//    wire                  q_we_a;
//    wire [95:0]           q_din_a, q_dout_b;

//    // =====================================================
//    // 1. INSTANTIATE KH?I QR-MGS CORE (DUT)
//    // =====================================================
//    qr_mgs_core #(
//        .DW(DW), .ADDR_W_PHI(ADDR_W_PHI), .ADDR_W_Q(ADDR_W_Q), .DOT_W(DOT_W)
//    ) u_mgs_core (
//        .clk(clk), .rst_n(rst_n), .start_core(start_core),
//        .lambda_i(lambda_in), .current_i(current_i), .M_rows_in(M_rows),
        
//        .phi_addr(phi_addr), .phi_data(phi_data),
//        .r_addr_a(r_addr_a), .r_we_a(r_we_a), .r_din_a(r_din_a),
//        .q_addr_a(q_addr_a), .q_we_a(q_we_a), .q_din_a(q_din_a),
//        .q_addr_b(q_addr_b), .q_dout_b(q_dout_b),
        
//        .core_done(core_done)
//    );
    

//    // Gán các tín hi?u n?i b? ra port ?? Debug (ILA peeking)
//    // L?u ý: C?n Mark Debug các wire này trong qr_mgs_core n?u dùng ILA
//    assign debug_u_val     = u_mgs_core.mac_result; // N?ng l??ng u
//    assign debug_rii_val   = u_mgs_core.r_ii_reg;   // 1/sqrt(u)
//    assign debug_alpha_val = u_mgs_core.r_ji_reg;   // Các h? s? Rji

//    // =====================================================
//    // 2. KH?I T?O CÁC IP BLOCK RAM (Xilinx BMG)
//    // =====================================================

//    // Ma tr?n ?o l??ng Phi (N?p s?n file .coe)
//    // Depth: 4096, Width: 96
//    phi_bram u_phi_mem (
//        .clka(clk),
//        .addra(phi_addr),
//        .douta(phi_data)
//    );

//    // Ma tr?n tr?c giao Q (True Dual Port)
//    // Port A: Ghi Qi m?i, Port B: ??c Qj c?
//    q_bram u_q_mem (
//        .clka(clk),
//        .wea(q_we_a),
//        .addra(q_addr_a),
//        .dina(q_din_a),
        
//        .clkb(clk),
//        .addrb(q_addr_b),
//        .doutb(q_dout_b)
//    );

//    // Ma tr?n R (L?u các h? s? Rji, Rii)
//    // Depth: 256, Width: 24
//    r_bram u_r_mem (
//        .clka(clk),
//        .wea(r_we_a),
//        .addra(r_addr_a),
//        .dina(r_din_a)
//    );

//endmodule


`timescale 1ns / 1ps

module qr_mgs_system_test_top #
(
    parameter DW = 24,
    parameter ADDR_W_PHI = 12,
    parameter ADDR_W_Q = 8,
    parameter DOT_W = 56
)
(
    input wire clk,
    input wire rst_n,
    input wire start_core,      // Xung b?t ??u (Trigger)
    input wire [7:0] lambda_in, // N?i v?i h?ng s? 183 (0xb7)
    input wire [4:0] current_i, // Vòng l?p OMP hi?n t?i
    input wire [3:0] M_rows,    // 15 cho 16x16

    // Output quan sát (Dành cho Debug/ILA)
    output wire core_done,
    output wire [DOT_W-1:0] debug_u_val,     // Giá tr? n?ng l??ng u (Q26)
    output wire [DW-1:0]    debug_alpha_val, // H? s? t??ng quan Rji (Q13)
    output wire [DW-1:0]    debug_rii_val,    // Giá tr? ISR 1/sqrt(u) (Q22)
    output wire [95:0]      debug_qi_out     // Vector Qi ??u ra
);

    // --- Signals k?t n?i n?i b? ---
    wire [ADDR_W_PHI-1:0] phi_addr_bus;
    wire [95:0]           phi_data_bus;

    wire [7:0]            r_addr_a_bus;
    wire                  r_we_a_bus;
    wire [23:0]           r_din_a_bus;

    wire [ADDR_W_Q-1:0]   q_addr_a_bus, q_addr_b_bus;
    wire                  q_we_a_bus;
    wire [95:0]           q_din_a_bus, q_dout_b_bus;

    // =====================================================
    // 1. KH?I T?O KH?I QR-MGS CORE (DUT)
    // =====================================================
    qr_mgs_core #(
        .DW(DW), 
        .ADDR_W_PHI(ADDR_W_PHI), 
        .ADDR_W_Q(ADDR_W_Q), 
        .DOT_W(DOT_W)
    ) u_mgs_core (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_core(start_core),
        .lambda_i(lambda_in), 
        .current_i(current_i), 
        .M_rows_in(M_rows),
        
        .phi_addr(phi_addr_bus), 
        .phi_data(phi_data_bus),
        
        .r_addr_a(r_addr_a_bus), 
        .r_we_a(r_we_a_bus), 
        .r_din_a(r_din_a_bus),
        
        .q_addr_a(q_addr_a_bus), 
        .q_we_a(q_we_a_bus), 
        .q_din_a(q_din_a_bus),
        
        .q_addr_b(q_addr_b_bus), 
        .q_dout_b(q_dout_b_bus),
        
        .qi_out(debug_qi_out), 
        .core_done(core_done)
    );

    // --- Peeking Signals ?? Debug ---
    assign debug_u_val     = u_mgs_core.mac_res;   // N?i tr?c ti?p vào wire MAC n?i b?
    assign debug_rii_val   = u_mgs_core.r_ii_reg;  // Giá tr? ISR ch?t ???c
    assign debug_alpha_val = u_mgs_core.r_ji_reg;  // Các h? s? t??ng quan

    // =====================================================
    // 2. KH?I T?O CÁC IP BLOCK RAM (Xilinx BMG)
    // =====================================================

    // Ma tr?n ?o l??ng Phi (N?p s?n file .coe c?a b?n)
    phi_bram u_phi_mem (
        .clka(clk),
        .addra(phi_addr_bus),
        .douta(phi_data_bus)
    );

    // Ma tr?n tr?c giao Q (True Dual Port RAM)
    // Port A: Ghi Qi m?i (Core), Port B: ??c Qj c? (Core)
    q_bram u_q_mem (
        .clka(clk),
        .wea(q_we_a_bus),
        .addra(q_addr_a_bus),
        .dina(q_din_a_bus),
        
        .clkb(clk),
        .addrb(q_addr_b_bus),
        .doutb(q_dout_b_bus)
    );

    // Ma tr?n R (L?u tr? các h? s? Rji và Rii)
    r_bram u_r_mem (
        .clka(clk),
        .wea(r_we_a_bus),
        .addra(r_addr_a_bus),
        .dina(r_din_a_bus)
    );

endmodule