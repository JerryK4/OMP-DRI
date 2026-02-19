//`timescale 1ns / 1ps

//module atom_selection_system_top #
//(
//    parameter DW      = 24,    // Q10.13
//    parameter ADDR_W  = 12,    // Phi RAM: 4096 rows
//    parameter ROW_W   = 6,     // r RAM: 16 rows (addr_w th?c t? c?a IP là 4)
//    parameter COL_W   = 8,     
//    parameter ROW_N   = 4,     
//    parameter DOT_W   = 48,    
//    parameter MAX_I   = 16,
//    parameter HIST_W  = 9
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start,
    
//    // Masking control t? FSM t?ng OMP
//    input  wire [$clog2(MAX_I):0]  current_i,
//    input  wire [MAX_I*HIST_W-1:0] lambda_history,

//    // Output k?t qu? cu?i cùng
//    output wire [COL_W-1:0]        lambda_out,
//    output wire                    atom_done
//);

//    // --- Tín hi?u k?t n?i n?i b? (Wires) ---
//    wire [ADDR_W-1:0] w_phi_addr;
//    wire [95:0]       w_phi_data;  // Bus 96-bit t? BRAM
//    wire [ROW_W-1:0]  w_r_addr;
//    wire [95:0]       w_r_data;    // Bus 96-bit t? BRAM

//    /* ==========================================================
//       1. Kh?i Logic Core (Module ?ã Test Pass)
//    ========================================================== */
//    atom_selection_top #(
//        .DW(DW), .ADDR_W(ADDR_W), .ROW_W(ROW_W), 
//        .COL_W(COL_W), .ROW_N(ROW_N), .DOT_W(DOT_W), 
//        .MAX_I(MAX_I), .HIST_W(HIST_W)
//    ) u_core (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start(start),
//        .N_cols(8'd255),       // 256 c?t
//        .M_rows(6'd15),        // 16 hàng
//        .phi_addr(w_phi_addr),
//        .phi_data(w_phi_data),
//        .r_addr(w_r_addr),
//        .r_data(w_r_data),
//        .current_i(current_i),
//        .lambda_history(lambda_history),
//        .lambda_out(lambda_out),
//        .atom_done(atom_done)
//    );

//    /* ==========================================================
//       2. IP BRAM ch?a Ma tr?n Phi (96-bit width, 4096 depth)
//    ========================================================== */
//    phi_bram u_phi_mem (
//        .clka(clk),
//        .addra(w_phi_addr),    // 12-bit
//        .douta(w_phi_data)     // 96-bit
//    );

//    /* ==========================================================
//       3. IP BRAM ch?a Th?ng d? r (96-bit width, 16 depth)
//    ========================================================== */
//    y_bram u_r_mem (
//        .clka(clk),
//        .addra(w_r_addr[3:0]), // Ch? l?y 4 bit th?p vì Depth=16
//        .douta(w_r_data)       // 96-bit
//    );

//endmodule


//`timescale 1ns / 1ps

//module atom_selection_system_top #
//(
//    parameter DW      = 24,    // Q10.13
//    parameter ADDR_W  = 12,    // Phi RAM: 4096 rows
//    parameter ROW_W   = 6,     // r RAM: 64 rows (addr_w th?c t? c?a IP là 4 cho Depth 16)
//    parameter COL_W   = 8,     
//    parameter ROW_N   = 4,     
//    parameter DOT_W   = 56,    // PH?I ??NG B? 56-BIT (Tránh l?i c?t bit d?u)
//    parameter MAX_I   = 16,
//    parameter HIST_W  = 9
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start,
    
//    // Masking control t? FSM t?ng OMP
//    input  wire [$clog2(MAX_I):0]  current_i,
//    input  wire [MAX_I*HIST_W-1:0] lambda_history,

//    // Output k?t qu? cu?i cùng
//    output wire [COL_W-1:0]        lambda_out,
//    output wire                    atom_done
//);

//    // --- Tín hi?u k?t n?i n?i b? (Wires) ---
//    wire [ADDR_W-1:0] w_phi_addr;
//    wire [95:0]       w_phi_data;  // Bus 96-bit t? IP BRAM
//    wire [ROW_W-1:0]  w_r_addr;
//    wire [95:0]       w_r_data;    // Bus 96-bit t? IP BRAM
//    wire [95:0] w_phi_dout; 
//    wire [95:0] w_r_dout;

//    /* ==========================================================
//       1. Kh?i Logic Core (Tích h?p module ?ã s?a ?? dây)
//    ========================================================== */
//    atom_selection_top #(
//        .DW(DW), .ADDR_W(ADDR_W), .ROW_W(ROW_W), 
//        .COL_W(COL_W), .ROW_N(ROW_N), .DOT_W(DOT_W), 
//        .MAX_I(MAX_I), .HIST_W(HIST_W)
//    ) u_core (
//        .clk(clk),
//        .rst_n(rst_n),
//        .start(start),
//        .N_cols(8'd255),       // Quét 256 c?t
//        .M_rows(6'd15),   // 16 hàng (m?i hàng 4 ph?n t? = 64 measurements)
//        .phi_addr(w_phi_addr),
//        .phi_data(w_phi_data),
//        .r_addr(w_r_addr),
//        .r_data(w_r_data),
//        .current_i(current_i),
//        .lambda_history(lambda_history),
//        .lambda_out(lambda_out),
//        .atom_done(atom_done)
//    );

//    /* ==========================================================
//       2. IP BRAM ch?a Ma tr?n Phi (DMD Patterns)
//       C?u hình trong IP Catalog: Standalone, Single Port ROM/RAM
//    ========================================================== */
//    phi_bram u_phi_mem (
//        .clka(clk),
//        .addra(w_phi_addr),    // 12-bit
//        .douta(w_phi_dout)     // ??i tên dây dout cho chu?n IP
//    );
//    assign w_phi_data = w_phi_dout;

//    /* ==========================================================
//       3. IP BRAM ch?a Th?ng d? r (Residual vector)
//       L?u ý: r thay ??i sau m?i vòng l?p OMP
//    ========================================================== */
//    y_bram u_r_mem (
//        .clka(clk),
//        .addra(w_r_addr[3:0]), // Slice 4 bit n?u IP Depth = 16
//        .douta(w_r_dout)       
//    );
//    assign w_r_data = w_r_dout;

//endmodule

`timescale 1ns / 1ps

module atom_selection_system_top #
(
    parameter DW      = 24,    // Q10.13
    parameter ADDR_W  = 12,    // Phi RAM: 4096 rows
    parameter ROW_W   = 6,     // r RAM: 64 rows
    parameter COL_W   = 8,     
    parameter ROW_N   = 4,     
    parameter DOT_W   = 56,    
    parameter MAX_I   = 16,
    parameter HIST_W  = 9
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    
    // Masking control t? FSM t?ng OMP
    input  wire [$clog2(MAX_I):0]  current_i,
    input  wire [MAX_I*HIST_W-1:0] lambda_history,

    // Output k?t qu? cu?i cùng
    output wire [COL_W-1:0]        lambda_out,
    output wire                    atom_done
);

    // --- Tín hi?u k?t n?i n?i b? ---
    wire [ADDR_W-1:0] w_phi_addr;
    wire [95:0]       w_phi_data;  
    wire [ROW_W-1:0]  w_r_addr;
    wire [95:0]       w_r_data;    
    
    wire [95:0] w_phi_dout; 
    wire [95:0] w_r_dout_a; // D? li?u t? Port A c?a y_bram

    /* ==========================================================
       1. Kh?i Logic Core (Atom Selection)
    ========================================================== */
    atom_selection_top #(
        .DW(DW), .ADDR_W(ADDR_W), .ROW_W(ROW_W), 
        .COL_W(COL_W), .ROW_N(ROW_N), .DOT_W(DOT_W), 
        .MAX_I(MAX_I), .HIST_W(HIST_W)
    ) u_core (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .N_cols(8'd255),       
        .M_rows(6'd15),   
        .phi_addr(w_phi_addr),
        .phi_data(w_phi_data),
        .r_addr(w_r_addr),
        .r_data(w_r_data),
        .current_i(current_i),
        .lambda_history(lambda_history),
        .lambda_out(lambda_out),
        .atom_done(atom_done)
    );

    /* ==========================================================
       2. IP BRAM Phi (Gi? nguyên Single Port)
    ========================================================== */
    phi_bram u_phi_mem (
        .clka(clk),
        .addra(w_phi_addr),    
        .douta(w_phi_dout)     
    );
    assign w_phi_data = w_phi_dout;

    /* ==========================================================
       3. IP BRAM Y - ??NH D?NG TRUE DUAL PORT
       Dùng Port A ?? c?p d? li?u cho kh?i Atom Selection
    ========================================================== */
    y_bram u_r_mem (
        // --- PORT A (K?t n?i v?i Core) ---
        .clka(clk),
        .wea(1'b0),                // Ch? ?? ??c (không ghi)
        .addra(w_r_addr[3:0]),     // ??a ch? 4-bit (cho Depth 16)
        .dina(96'd0),              // Không có d? li?u vào
        .douta(w_r_dout_a),        // D? li?u ra
        
        // --- PORT B (T?m th?i tie-off ho?c ?? tr?ng cho external) ---
        .clkb(clk),
        .web(1'b0),
        .addrb(4'd0),
        .dinb(96'd0),
        .doutb()                   // C?ng này s? n?i v?i Final Estimation sau này
    );
    
    assign w_r_data = w_r_dout_a;

endmodule