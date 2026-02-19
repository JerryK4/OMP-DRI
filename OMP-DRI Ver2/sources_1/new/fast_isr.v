//`timescale 1ns / 1ps

//module fast_isr #
//(
//    parameter IN_W  = 56,    // ??u vào u t? MAC (Qxx.26)
//    parameter OUT_W = 24     // ??u ra y_out (Q2.22)
//)
//(
//    input  wire clk,
//    input  wire rst_n,
//    input  wire start,
//    input  wire [IN_W-1:0] u_in,
    
//    output reg [OUT_W-1:0] y_out,
//    output reg             done
//);

//    // FSM States
//    localparam IDLE    = 3'd0,
//               LOOKUP  = 3'd1,
//               CALC_1  = 3'd2, // Tính y0 * y0
//               CALC_2  = 3'd3, // Tính u * (y0^2)
//               CALC_3  = 3'd4, // Tính 3.0 - (u*y0^2)
//               CALC_4  = 3'd5, // Tính y0 * diff
//               FINISH  = 3'd6;

//    reg [2:0] state;
//    reg [IN_W-1:0] u_reg;
//    reg [23:0]     y_initial;
    
//    // Các thanh ghi trung gian m? r?ng bit ?? tránh tràn
//    reg signed [47:0]  y0_sq_q44;
//    reg signed [103:0] u_y2_q70;
//    reg signed [31:0]  diff_q22;
//    reg signed [63:0]  prod_final_q44;
    
//    // H?ng s? 3.0 ??nh d?ng Q22 = 3 * 2^22 = 12582912
//    wire signed [31:0] CONST_3_Q22 = 32'sd12582912;

//    // --- LOGIC CH?N ??A CH? LUT ---
//    // u = index / 32. Index 32 t??ng ?ng u = 1.0 (bit 26)
//    // L?y 8 bit t? bit 21 ??n 28 c?a u_in
//    wire [7:0] lut_addr = (u_in[IN_W-1:29] != 0) ? 8'hFF : u_in[28:21];

//    // --- B?NG TRA LUT (Include file MATLAB c?a b?n) ---
//    always @(posedge clk) begin
//        // Fast ISR LUT Table (Q2.22 Format)
//        case(lut_addr)
//            8'h00: y_initial <= 24'hFFFFFF;
//            8'h01: y_initial <= 24'hFFFFFF;
//            8'h02: y_initial <= 24'hFFFFFF;
//            8'h03: y_initial <= 24'hD105EC;
//            8'h04: y_initial <= 24'hB504F3;
//            8'h05: y_initial <= 24'hA1E89B;
//            8'h06: y_initial <= 24'h93CD3A;
//            8'h07: y_initial <= 24'h88D677;
//            8'h08: y_initial <= 24'h800000;
//            8'h09: y_initial <= 24'h78ADF7;
//            8'h0A: y_initial <= 24'h727C97;
//            8'h0B: y_initial <= 24'h6D28A5;
//            8'h0C: y_initial <= 24'h6882F6;
//            8'h0D: y_initial <= 24'h646956;
//            8'h0E: y_initial <= 24'h60C248;
//            8'h0F: y_initial <= 24'h5D7A5D;
//            8'h10: y_initial <= 24'h5A827A;
//            8'h11: y_initial <= 24'h57CEAA;
//            8'h12: y_initial <= 24'h555555;
//            8'h13: y_initial <= 24'h530EB0;
//            8'h14: y_initial <= 24'h50F44E;
//            8'h15: y_initial <= 24'h4F00D9;
//            8'h16: y_initial <= 24'h4D2FD9;
//            8'h17: y_initial <= 24'h4B7D83;
//            8'h18: y_initial <= 24'h49E69D;
//            8'h19: y_initial <= 24'h486861;
//            8'h1A: y_initial <= 24'h47006B;
//            8'h1B: y_initial <= 24'h45ACA4;
//            8'h1C: y_initial <= 24'h446B3C;
//            8'h1D: y_initial <= 24'h433A99;
//            8'h1E: y_initial <= 24'h421953;
//            8'h1F: y_initial <= 24'h410629;
//            8'h20: y_initial <= 24'h400000;
//            8'h21: y_initial <= 24'h3F05D9;
//            8'h22: y_initial <= 24'h3E16D1;
//            8'h23: y_initial <= 24'h3D321A;
//            8'h24: y_initial <= 24'h3C56FC;
//            8'h25: y_initial <= 24'h3B84CF;
//            8'h26: y_initial <= 24'h3ABAFD;
//            8'h27: y_initial <= 24'h39F8FB;
//            8'h28: y_initial <= 24'h393E4C;
//            8'h29: y_initial <= 24'h388A7B;
//            8'h2A: y_initial <= 24'h37DD21;
//            8'h2B: y_initial <= 24'h3735DB;
//            8'h2C: y_initial <= 24'h369452;
//            8'h2D: y_initial <= 24'h35F834;
//            8'h2E: y_initial <= 24'h356133;
//            8'h2F: y_initial <= 24'h34CF0B;
//            8'h30: y_initial <= 24'h34417B;
//            8'h31: y_initial <= 24'h33B845;
//            8'h32: y_initial <= 24'h333333;
//            8'h33: y_initial <= 24'h32B210;
//            8'h34: y_initial <= 24'h3234AB;
//            8'h35: y_initial <= 24'h31BAD7;
//            8'h36: y_initial <= 24'h314469;
//            8'h37: y_initial <= 24'h30D13A;
//            8'h38: y_initial <= 24'h306124;
//            8'h39: y_initial <= 24'h2FF404;
//            8'h3A: y_initial <= 24'h2F89BB;
//            8'h3B: y_initial <= 24'h2F2228;
//            8'h3C: y_initial <= 24'h2EBD2F;
//            8'h3D: y_initial <= 24'h2E5AB4;
//            8'h3E: y_initial <= 24'h2DFA9D;
//            8'h3F: y_initial <= 24'h2D9CD2;
//            8'h40: y_initial <= 24'h2D413D;
//            8'h41: y_initial <= 24'h2CE7C6;
//            8'h42: y_initial <= 24'h2C905A;
//            8'h43: y_initial <= 24'h2C3AE5;
//            8'h44: y_initial <= 24'h2BE755;
//            8'h45: y_initial <= 24'h2B9597;
//            8'h46: y_initial <= 24'h2B459B;
//            8'h47: y_initial <= 24'h2AF751;
//            8'h48: y_initial <= 24'h2AAAAB;
//            8'h49: y_initial <= 24'h2A5F99;
//            8'h4A: y_initial <= 24'h2A160D;
//            8'h4B: y_initial <= 24'h29CDFC;
//            8'h4C: y_initial <= 24'h298758;
//            8'h4D: y_initial <= 24'h294215;
//            8'h4E: y_initial <= 24'h28FE29;
//            8'h4F: y_initial <= 24'h28BB87;
//            8'h50: y_initial <= 24'h287A27;
//            8'h51: y_initial <= 24'h2839FD;
//            8'h52: y_initial <= 24'h27FB01;
//            8'h53: y_initial <= 24'h27BD29;
//            8'h54: y_initial <= 24'h27806D;
//            8'h55: y_initial <= 24'h2744C3;
//            8'h56: y_initial <= 24'h270A25;
//            8'h57: y_initial <= 24'h26D08B;
//            8'h58: y_initial <= 24'h2697EC;
//            8'h59: y_initial <= 24'h266043;
//            8'h5A: y_initial <= 24'h262988;
//            8'h5B: y_initial <= 24'h25F3B4;
//            8'h5C: y_initial <= 24'h25BEC2;
//            8'h5D: y_initial <= 24'h258AAA;
//            8'h5E: y_initial <= 24'h255768;
//            8'h5F: y_initial <= 24'h2524F6;
//            8'h60: y_initial <= 24'h24F34F;
//            8'h61: y_initial <= 24'h24C26C;
//            8'h62: y_initial <= 24'h249249;
//            8'h63: y_initial <= 24'h2462E2;
//            8'h64: y_initial <= 24'h243431;
//            8'h65: y_initial <= 24'h240632;
//            8'h66: y_initial <= 24'h23D8E0;
//            8'h67: y_initial <= 24'h23AC38;
//            8'h68: y_initial <= 24'h238035;
//            8'h69: y_initial <= 24'h2354D4;
//            8'h6A: y_initial <= 24'h232A10;
//            8'h6B: y_initial <= 24'h22FFE6;
//            8'h6C: y_initial <= 24'h22D652;
//            8'h6D: y_initial <= 24'h22AD51;
//            8'h6E: y_initial <= 24'h2284DF;
//            8'h6F: y_initial <= 24'h225CFA;
//            8'h70: y_initial <= 24'h22359E;
//            8'h71: y_initial <= 24'h220EC8;
//            8'h72: y_initial <= 24'h21E875;
//            8'h73: y_initial <= 24'h21C2A2;
//            8'h74: y_initial <= 24'h219D4C;
//            8'h75: y_initial <= 24'h217872;
//            8'h76: y_initial <= 24'h21540F;
//            8'h77: y_initial <= 24'h213023;
//            8'h78: y_initial <= 24'h210CA9;
//            8'h79: y_initial <= 24'h20E9A1;
//            8'h7A: y_initial <= 24'h20C706;
//            8'h7B: y_initial <= 24'h20A4D8;
//            8'h7C: y_initial <= 24'h208315;
//            8'h7D: y_initial <= 24'h2061B9;
//            8'h7E: y_initial <= 24'h2040C3;
//            8'h7F: y_initial <= 24'h202030;
//            8'h80: y_initial <= 24'h200000;
//            8'h81: y_initial <= 24'h1FE030;
//            8'h82: y_initial <= 24'h1FC0BE;
//            8'h83: y_initial <= 24'h1FA1A8;
//            8'h84: y_initial <= 24'h1F82ED;
//            8'h85: y_initial <= 24'h1F648A;
//            8'h86: y_initial <= 24'h1F467F;
//            8'h87: y_initial <= 24'h1F28CA;
//            8'h88: y_initial <= 24'h1F0B68;
//            8'h89: y_initial <= 24'h1EEE59;
//            8'h8A: y_initial <= 24'h1ED19B;
//            8'h8B: y_initial <= 24'h1EB52D;
//            8'h8C: y_initial <= 24'h1E990D;
//            8'h8D: y_initial <= 24'h1E7D39;
//            8'h8E: y_initial <= 24'h1E61B1;
//            8'h8F: y_initial <= 24'h1E4673;
//            8'h90: y_initial <= 24'h1E2B7E;
//            8'h91: y_initial <= 24'h1E10D0;
//            8'h92: y_initial <= 24'h1DF669;
//            8'h93: y_initial <= 24'h1DDC46;
//            8'h94: y_initial <= 24'h1DC268;
//            8'h95: y_initial <= 24'h1DA8CC;
//            8'h96: y_initial <= 24'h1D8F72;
//            8'h97: y_initial <= 24'h1D7659;
//            8'h98: y_initial <= 24'h1D5D7F;
//            8'h99: y_initial <= 24'h1D44E3;
//            8'h9A: y_initial <= 24'h1D2C85;
//            8'h9B: y_initial <= 24'h1D1464;
//            8'h9C: y_initial <= 24'h1CFC7E;
//            8'h9D: y_initial <= 24'h1CE4D2;
//            8'h9E: y_initial <= 24'h1CCD60;
//            8'h9F: y_initial <= 24'h1CB627;
//            8'hA0: y_initial <= 24'h1C9F26;
//            8'hA1: y_initial <= 24'h1C885B;
//            8'hA2: y_initial <= 24'h1C71C7;
//            8'hA3: y_initial <= 24'h1C5B68;
//            8'hA4: y_initial <= 24'h1C453E;
//            8'hA5: y_initial <= 24'h1C2F47;
//            8'hA6: y_initial <= 24'h1C1983;
//            8'hA7: y_initial <= 24'h1C03F1;
//            8'hA8: y_initial <= 24'h1BEE90;
//            8'hA9: y_initial <= 24'h1BD960;
//            8'hAA: y_initial <= 24'h1BC461;
//            8'hAB: y_initial <= 24'h1BAF90;
//            8'hAC: y_initial <= 24'h1B9AEE;
//            8'hAD: y_initial <= 24'h1B8679;
//            8'hAE: y_initial <= 24'h1B7232;
//            8'hAF: y_initial <= 24'h1B5E18;
//            8'hB0: y_initial <= 24'h1B4A29;
//            8'hB1: y_initial <= 24'h1B3666;
//            8'hB2: y_initial <= 24'h1B22CD;
//            8'hB3: y_initial <= 24'h1B0F5F;
//            8'hB4: y_initial <= 24'h1AFC1A;
//            8'hB5: y_initial <= 24'h1AE8FE;
//            8'hB6: y_initial <= 24'h1AD60A;
//            8'hB7: y_initial <= 24'h1AC33E;
//            8'hB8: y_initial <= 24'h1AB09A;
//            8'hB9: y_initial <= 24'h1A9E1C;
//            8'hBA: y_initial <= 24'h1A8BC4;
//            8'hBB: y_initial <= 24'h1A7992;
//            8'hBC: y_initial <= 24'h1A6786;
//            8'hBD: y_initial <= 24'h1A559E;
//            8'hBE: y_initial <= 24'h1A43DA;
//            8'hBF: y_initial <= 24'h1A323A;
//            8'hC0: y_initial <= 24'h1A20BD;
//            8'hC1: y_initial <= 24'h1A0F64;
//            8'hC2: y_initial <= 24'h19FE2C;
//            8'hC3: y_initial <= 24'h19ED17;
//            8'hC4: y_initial <= 24'h19DC23;
//            8'hC5: y_initial <= 24'h19CB50;
//            8'hC6: y_initial <= 24'h19BA9E;
//            8'hC7: y_initial <= 24'h19AA0C;
//            8'hC8: y_initial <= 24'h19999A;
//            8'hC9: y_initial <= 24'h198947;
//            8'hCA: y_initial <= 24'h197913;
//            8'hCB: y_initial <= 24'h1968FE;
//            8'hCC: y_initial <= 24'h195908;
//            8'hCD: y_initial <= 24'h19492F;
//            8'hCE: y_initial <= 24'h193974;
//            8'hCF: y_initial <= 24'h1929D6;
//            8'hD0: y_initial <= 24'h191A55;
//            8'hD1: y_initial <= 24'h190AF1;
//            8'hD2: y_initial <= 24'h18FBA9;
//            8'hD3: y_initial <= 24'h18EC7C;
//            8'hD4: y_initial <= 24'h18DD6B;
//            8'hD5: y_initial <= 24'h18CE76;
//            8'hD6: y_initial <= 24'h18BF9B;
//            8'hD7: y_initial <= 24'h18B0DA;
//            8'hD8: y_initial <= 24'h18A234;
//            8'hD9: y_initial <= 24'h1893A8;
//            8'hDA: y_initial <= 24'h188536;
//            8'hDB: y_initial <= 24'h1876DD;
//            8'hDC: y_initial <= 24'h18689D;
//            8'hDD: y_initial <= 24'h185A76;
//            8'hDE: y_initial <= 24'h184C67;
//            8'hDF: y_initial <= 24'h183E70;
//            8'hE0: y_initial <= 24'h183092;
//            8'hE1: y_initial <= 24'h1822CB;
//            8'hE2: y_initial <= 24'h18151C;
//            8'hE3: y_initial <= 24'h180784;
//            8'hE4: y_initial <= 24'h17FA02;
//            8'hE5: y_initial <= 24'h17EC98;
//            8'hE6: y_initial <= 24'h17DF43;
//            8'hE7: y_initial <= 24'h17D205;
//            8'hE8: y_initial <= 24'h17C4DD;
//            8'hE9: y_initial <= 24'h17B7CB;
//            8'hEA: y_initial <= 24'h17AACE;
//            8'hEB: y_initial <= 24'h179DE7;
//            8'hEC: y_initial <= 24'h179114;
//            8'hED: y_initial <= 24'h178456;
//            8'hEE: y_initial <= 24'h1777AD;
//            8'hEF: y_initial <= 24'h176B18;
//            8'hF0: y_initial <= 24'h175E97;
//            8'hF1: y_initial <= 24'h17522A;
//            8'hF2: y_initial <= 24'h1745D1;
//            8'hF3: y_initial <= 24'h17398C;
//            8'hF4: y_initial <= 24'h172D5A;
//            8'hF5: y_initial <= 24'h17213B;
//            8'hF6: y_initial <= 24'h17152F;
//            8'hF7: y_initial <= 24'h170935;
//            8'hF8: y_initial <= 24'h16FD4E;
//            8'hF9: y_initial <= 24'h16F17A;
//            8'hFA: y_initial <= 24'h16E5B8;
//            8'hFB: y_initial <= 24'h16DA08;
//            8'hFC: y_initial <= 24'h16CE69;
//            8'hFD: y_initial <= 24'h16C2DC;
//            8'hFE: y_initial <= 24'h16B761;
//            8'hFF: y_initial <= 24'h16ABF7;
//            default: y_initial <= 24'h400000; // Default = 1.0 (Hex 400000)
//        endcase
//    end

//    // --- FSM TÍNH TOÁN NEWTON-RAPHSON ---
//    // Công th?c: y = 0.5 * y0 * (3 - u * y0^2)
////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            state <= IDLE;
////            done  <= 0;
////            y_out <= 0;
////        end else begin
////            case (state)
////                IDLE: begin
////                    done <= 0;
////                    if (start) begin
////                        u_reg <= u_in;
////                        state <= LOOKUP;
////                    end
////                end

////                LOOKUP: begin
////                    // ??i 1 chu k? ?? y_initial t? BRAM/Case s?n sàng
////                    state <= CALC_1;
////                end

////                CALC_1: begin
////                    // B??c 1: y0^2 (Q2.22 * Q2.22 = Q4.44)
////                    y0_sq_q44 <= $signed({1'b0, y_initial}) * $signed({1'b0, y_initial});
////                    state <= CALC_2;
////                end

////                CALC_2: begin
////                    // B??c 2: u * y0^2 (Qxx.26 * Q4.44 = Qxx.70)
////                    u_y2_q70 <= $signed({1'b0, u_reg}) * y0_sq_q44;
////                    state <= CALC_3;
////                end

////                CALC_3: begin
////                    // B??c 3: diff = 3.0 - (u * y0^2)
////                    // Chuy?n Q70 v? Q22 b?ng cách d?ch ph?i 48 bit
////                    diff_q22 <= CONST_3_Q22 - $signed(u_y2_q70 >>> 48);
////                    state <= CALC_4;
////                end

////                CALC_4: begin
////                    // B??c 4: y_next = y0 * diff (Q2.22 * Q22 = Q44)
////                    prod_final_q44 <= $signed({1'b0, y_initial}) * diff_q22;
////                    state <= FINISH;
////                end

////                FINISH: begin
////                    // B??c 5: K?t qu? = 0.5 * y_next
////                    // Chuy?n Q44 v? Q22 (d?ch 22), nhân 0.5 (d?ch thêm 1) => T?ng d?ch 23
////                    y_out <= $unsigned(prod_final_q44 >>> 23);
////                    done  <= 1'b1;
////                    state <= IDLE;
////                end

////                default: state <= IDLE;
////            endcase
////        end
//        always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= IDLE; done <= 0; y_out <= 0;
//        end else begin
//            case (state)
//                IDLE: begin
//                    done <= 0;
//                    if (start) begin u_reg <= u_in; state <= LOOKUP; end
//                end

//                LOOKUP: state <= CALC_1;

//                CALC_1: begin
//                    y0_sq_q44 <= $signed({1'b0, y_initial}) * $signed({1'b0, y_initial});
//                    state <= CALC_2;
//                end

//                CALC_2: begin
//                    u_y2_q70 <= $signed({1'b0, u_reg}) * y0_sq_q44;
//                    state <= CALC_3;
//                end

//                CALC_3: begin
//                    // Tính diff = 3.0 - (u * y0^2)
//                    diff_q22 <= CONST_3_Q22 - $signed(u_y2_q70 >>> 48);
//                    state <= CALC_4;
//                end

//                CALC_4: begin
//                    // KI?M TRA AN TOÀN: N?u u quá l?n làm diff âm, b? qua NR, dùng luôn y_initial
//                    if (diff_q22[31]) begin // Bit d?u c?a diff là 1 (s? âm)
//                        prod_final_q44 <= $signed({1'b0, y_initial}) << 23; // Gi? l?p ?? ra y_initial ? b??c sau
//                        state <= FINISH;
//                    end else begin
//                        prod_final_q44 <= $signed({1'b0, y_initial}) * diff_q22;
//                        state <= FINISH;
//                    end
//                end

//                FINISH: begin
//                    y_out <= $unsigned(prod_final_q44 >>> 23);
//                    done  <= 1'b1;
//                    state <= IDLE;
//                end
//                default: state <= IDLE;
//            endcase
//        end
//    end
//endmodule

`timescale 1ns / 1ps

module fast_isr #
(
    parameter IN_W  = 56,    // ??u vào u t? MAC (Qxx.26)
    parameter OUT_W = 24     // ??u ra y_out (Q2.22)
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire [IN_W-1:0] u_in,
    
    output reg [OUT_W-1:0] y_out,
    output reg             done
);

    // --- FSM States ---
    localparam IDLE    = 3'd0,
               CALC_1  = 3'd1, // Tính y0^2 (Q4.44)
               CALC_2  = 3'd2, // Tính u * y0^2 (Qxx.70)
               CALC_3  = 3'd3, // Tính 3.0 - (u*y0^2) (Q22)
               CALC_4  = 4'd4, // Tính y0 * diff (Q44)
               FINISH  = 3'd5;

    reg [2:0] state;
    reg [IN_W-1:0] u_reg;
    reg [23:0]     y_initial; // Output t? LUT t? h?p
    
    reg signed [47:0]  y0_sq_q44;
    reg signed [103:0] u_y2_q70;
    reg signed [31:0]  diff_q22;
    reg signed [63:0]  prod_final_q44;
    
    localparam signed [31:0] CONST_3_Q22 = 32'sd12582912; // 3.0 in Q22

    // --- 1. LUT T? H?P (u = index / 16) ---
    // Vì u=1.0 n?m ? bit 26 c?a u_in, nên ?? có index = u*16 (u*2^4), 
    // ta l?y u_in / 2^22. V?y ??a ch? LUT là u_in[29:22].
    wire [7:0] lut_addr = (u_in[IN_W-1:30] != 0) ? 8'hFF : u_in[29:22];

    always @(*) begin
        case(lut_addr)
            8'h00: y_initial = 24'hFFFFFF;
            8'h01: y_initial = 24'hFFFFFF;
            8'h02: y_initial = 24'hB504F3;
            8'h03: y_initial = 24'h93CD3A;
            8'h04: y_initial = 24'h800000;
            8'h05: y_initial = 24'h727C97;
            8'h06: y_initial = 24'h6882F6;
            8'h07: y_initial = 24'h60C248;
            8'h08: y_initial = 24'h5A827A;
            8'h09: y_initial = 24'h555555;
            8'h0A: y_initial = 24'h50F44E;
            8'h0B: y_initial = 24'h4D2FD9;
            8'h0C: y_initial = 24'h49E69D;
            8'h0D: y_initial = 24'h47006B;
            8'h0E: y_initial = 24'h446B3C;
            8'h0F: y_initial = 24'h421953;
            8'h10: y_initial = 24'h400000;
            8'h11: y_initial = 24'h3E16D1;
            8'h12: y_initial = 24'h3C56FC;
            8'h13: y_initial = 24'h3ABAFD;
            8'h14: y_initial = 24'h393E4C;
            8'h15: y_initial = 24'h37DD21;
            8'h16: y_initial = 24'h369452;
            8'h17: y_initial = 24'h356133;
            8'h18: y_initial = 24'h34417B;
            8'h19: y_initial = 24'h333333;
            8'h1A: y_initial = 24'h3234AB;
            8'h1B: y_initial = 24'h314469;
            8'h1C: y_initial = 24'h306124;
            8'h1D: y_initial = 24'h2F89BB;
            8'h1E: y_initial = 24'h2EBD2F;
            8'h1F: y_initial = 24'h2DFA9D;
            8'h20: y_initial = 24'h2D413D;
            8'h21: y_initial = 24'h2C905A;
            8'h22: y_initial = 24'h2BE755;
            8'h23: y_initial = 24'h2B459B;
            8'h24: y_initial = 24'h2AAAAB;
            8'h25: y_initial = 24'h2A160D;
            8'h26: y_initial = 24'h298758;
            8'h27: y_initial = 24'h28FE29;
            8'h28: y_initial = 24'h287A27;
            8'h29: y_initial = 24'h27FB01;
            8'h2A: y_initial = 24'h27806D;
            8'h2B: y_initial = 24'h270A25;
            8'h2C: y_initial = 24'h2697EC;
            8'h2D: y_initial = 24'h262988;
            8'h2E: y_initial = 24'h25BEC2;
            8'h2F: y_initial = 24'h255768;
            8'h30: y_initial = 24'h24F34F;
            8'h31: y_initial = 24'h249249;
            8'h32: y_initial = 24'h243431;
            8'h33: y_initial = 24'h23D8E0;
            8'h34: y_initial = 24'h238035;
            8'h35: y_initial = 24'h232A10;
            8'h36: y_initial = 24'h22D652;
            8'h37: y_initial = 24'h2284DF;
            8'h38: y_initial = 24'h22359E;
            8'h39: y_initial = 24'h21E875;
            8'h3A: y_initial = 24'h219D4C;
            8'h3B: y_initial = 24'h21540F;
            8'h3C: y_initial = 24'h210CA9;
            8'h3D: y_initial = 24'h20C706;
            8'h3E: y_initial = 24'h208315;
            8'h3F: y_initial = 24'h2040C3;
            8'h40: y_initial = 24'h200000;
            8'h41: y_initial = 24'h1FC0BE;
            8'h42: y_initial = 24'h1F82ED;
            8'h43: y_initial = 24'h1F467F;
            8'h44: y_initial = 24'h1F0B68;
            8'h45: y_initial = 24'h1ED19B;
            8'h46: y_initial = 24'h1E990D;
            8'h47: y_initial = 24'h1E61B1;
            8'h48: y_initial = 24'h1E2B7E;
            8'h49: y_initial = 24'h1DF669;
            8'h4A: y_initial = 24'h1DC268;
            8'h4B: y_initial = 24'h1D8F72;
            8'h4C: y_initial = 24'h1D5D7F;
            8'h4D: y_initial = 24'h1D2C85;
            8'h4E: y_initial = 24'h1CFC7E;
            8'h4F: y_initial = 24'h1CCD60;
            8'h50: y_initial = 24'h1C9F26;
            8'h51: y_initial = 24'h1C71C7;
            8'h52: y_initial = 24'h1C453E;
            8'h53: y_initial = 24'h1C1983;
            8'h54: y_initial = 24'h1BEE90;
            8'h55: y_initial = 24'h1BC461;
            8'h56: y_initial = 24'h1B9AEE;
            8'h57: y_initial = 24'h1B7232;
            8'h58: y_initial = 24'h1B4A29;
            8'h59: y_initial = 24'h1B22CD;
            8'h5A: y_initial = 24'h1AFC1A;
            8'h5B: y_initial = 24'h1AD60A;
            8'h5C: y_initial = 24'h1AB09A;
            8'h5D: y_initial = 24'h1A8BC4;
            8'h5E: y_initial = 24'h1A6786;
            8'h5F: y_initial = 24'h1A43DA;
            8'h60: y_initial = 24'h1A20BD;
            8'h61: y_initial = 24'h19FE2C;
            8'h62: y_initial = 24'h19DC23;
            8'h63: y_initial = 24'h19BA9E;
            8'h64: y_initial = 24'h19999A;
            8'h65: y_initial = 24'h197913;
            8'h66: y_initial = 24'h195908;
            8'h67: y_initial = 24'h193974;
            8'h68: y_initial = 24'h191A55;
            8'h69: y_initial = 24'h18FBA9;
            8'h6A: y_initial = 24'h18DD6B;
            8'h6B: y_initial = 24'h18BF9B;
            8'h6C: y_initial = 24'h18A234;
            8'h6D: y_initial = 24'h188536;
            8'h6E: y_initial = 24'h18689D;
            8'h6F: y_initial = 24'h184C67;
            8'h70: y_initial = 24'h183092;
            8'h71: y_initial = 24'h18151C;
            8'h72: y_initial = 24'h17FA02;
            8'h73: y_initial = 24'h17DF43;
            8'h74: y_initial = 24'h17C4DD;
            8'h75: y_initial = 24'h17AACE;
            8'h76: y_initial = 24'h179114;
            8'h77: y_initial = 24'h1777AD;
            8'h78: y_initial = 24'h175E97;
            8'h79: y_initial = 24'h1745D1;
            8'h7A: y_initial = 24'h172D5A;
            8'h7B: y_initial = 24'h17152F;
            8'h7C: y_initial = 24'h16FD4E;
            8'h7D: y_initial = 24'h16E5B8;
            8'h7E: y_initial = 24'h16CE69;
            8'h7F: y_initial = 24'h16B761;
            8'h80: y_initial = 24'h16A09E;
            8'h81: y_initial = 24'h168A20;
            8'h82: y_initial = 24'h1673E3;
            8'h83: y_initial = 24'h165DE8;
            8'h84: y_initial = 24'h16482D;
            8'h85: y_initial = 24'h1632B1;
            8'h86: y_initial = 24'h161D73;
            8'h87: y_initial = 24'h160871;
            8'h88: y_initial = 24'h15F3AA;
            8'h89: y_initial = 24'h15DF1E;
            8'h8A: y_initial = 24'h15CACB;
            8'h8B: y_initial = 24'h15B6B1;
            8'h8C: y_initial = 24'h15A2CE;
            8'h8D: y_initial = 24'h158F20;
            8'h8E: y_initial = 24'h157BA9;
            8'h8F: y_initial = 24'h156865;
            8'h90: y_initial = 24'h155555;
            8'h91: y_initial = 24'h154278;
            8'h92: y_initial = 24'h152FCC;
            8'h93: y_initial = 24'h151D51;
            8'h94: y_initial = 24'h150B07;
            8'h95: y_initial = 24'h14F8EB;
            8'h96: y_initial = 24'h14E6FE;
            8'h97: y_initial = 24'h14D53E;
            8'h98: y_initial = 24'h14C3AC;
            8'h99: y_initial = 24'h14B246;
            8'h9A: y_initial = 24'h14A10B;
            8'h9B: y_initial = 24'h148FFA;
            8'h9C: y_initial = 24'h147F14;
            8'h9D: y_initial = 24'h146E58;
            8'h9E: y_initial = 24'h145DC4;
            8'h9F: y_initial = 24'h144D58;
            8'hA0: y_initial = 24'h143D13;
            8'hA1: y_initial = 24'h142CF6;
            8'hA2: y_initial = 24'h141CFF;
            8'hA3: y_initial = 24'h140D2D;
            8'hA4: y_initial = 24'h13FD80;
            8'hA5: y_initial = 24'h13EDF8;
            8'hA6: y_initial = 24'h13DE95;
            8'hA7: y_initial = 24'h13CF54;
            8'hA8: y_initial = 24'h13C036;
            8'hA9: y_initial = 24'h13B13B;
            8'hAA: y_initial = 24'h13A262;
            8'hAB: y_initial = 24'h1393AA;
            8'hAC: y_initial = 24'h138513;
            8'hAD: y_initial = 24'h13769C;
            8'hAE: y_initial = 24'h136845;
            8'hAF: y_initial = 24'h135A0E;
            8'hB0: y_initial = 24'h134BF6;
            8'hB1: y_initial = 24'h133DFD;
            8'hB2: y_initial = 24'h133022;
            8'hB3: y_initial = 24'h132264;
            8'hB4: y_initial = 24'h1314C4;
            8'hB5: y_initial = 24'h130741;
            8'hB6: y_initial = 24'h12F9DA;
            8'hB7: y_initial = 24'h12EC8F;
            8'hB8: y_initial = 24'h12DF61;
            8'hB9: y_initial = 24'h12D24D;
            8'hBA: y_initial = 24'h12C555;
            8'hBB: y_initial = 24'h12B878;
            8'hBC: y_initial = 24'h12ABB4;
            8'hBD: y_initial = 24'h129F0B;
            8'hBE: y_initial = 24'h12927B;
            8'hBF: y_initial = 24'h128605;
            8'hC0: y_initial = 24'h1279A7;
            8'hC1: y_initial = 24'h126D62;
            8'hC2: y_initial = 24'h126136;
            8'hC3: y_initial = 24'h125521;
            8'hC4: y_initial = 24'h124925;
            8'hC5: y_initial = 24'h123D3F;
            8'hC6: y_initial = 24'h123171;
            8'hC7: y_initial = 24'h1225B9;
            8'hC8: y_initial = 24'h121A18;
            8'hC9: y_initial = 24'h120E8E;
            8'hCA: y_initial = 24'h120319;
            8'hCB: y_initial = 24'h11F7BA;
            8'hCC: y_initial = 24'h11EC70;
            8'hCD: y_initial = 24'h11E13C;
            8'hCE: y_initial = 24'h11D61C;
            8'hCF: y_initial = 24'h11CB11;
            8'hD0: y_initial = 24'h11C01B;
            8'hD1: y_initial = 24'h11B538;
            8'hD2: y_initial = 24'h11AA6A;
            8'hD3: y_initial = 24'h119FAF;
            8'hD4: y_initial = 24'h119508;
            8'hD5: y_initial = 24'h118A74;
            8'hD6: y_initial = 24'h117FF3;
            8'hD7: y_initial = 24'h117585;
            8'hD8: y_initial = 24'h116B29;
            8'hD9: y_initial = 24'h1160E0;
            8'hDA: y_initial = 24'h1156A8;
            8'hDB: y_initial = 24'h114C83;
            8'hDC: y_initial = 24'h114270;
            8'hDD: y_initial = 24'h11386E;
            8'hDE: y_initial = 24'h112E7D;
            8'hDF: y_initial = 24'h11249D;
            8'hE0: y_initial = 24'h111ACF;
            8'hE1: y_initial = 24'h111111;
            8'hE2: y_initial = 24'h110764;
            8'hE3: y_initial = 24'h10FDC7;
            8'hE4: y_initial = 24'h10F43A;
            8'hE5: y_initial = 24'h10EABE;
            8'hE6: y_initial = 24'h10E151;
            8'hE7: y_initial = 24'h10D7F4;
            8'hE8: y_initial = 24'h10CEA6;
            8'hE9: y_initial = 24'h10C568;
            8'hEA: y_initial = 24'h10BC39;
            8'hEB: y_initial = 24'h10B319;
            8'hEC: y_initial = 24'h10AA08;
            8'hED: y_initial = 24'h10A105;
            8'hEE: y_initial = 24'h109811;
            8'hEF: y_initial = 24'h108F2C;
            8'hF0: y_initial = 24'h108655;
            8'hF1: y_initial = 24'h107D8B;
            8'hF2: y_initial = 24'h1074D0;
            8'hF3: y_initial = 24'h106C23;
            8'hF4: y_initial = 24'h106383;
            8'hF5: y_initial = 24'h105AF1;
            8'hF6: y_initial = 24'h10526C;
            8'hF7: y_initial = 24'h1049F5;
            8'hF8: y_initial = 24'h10418A;
            8'hF9: y_initial = 24'h10392D;
            8'hFA: y_initial = 24'h1030DC;
            8'hFB: y_initial = 24'h102898;
            8'hFC: y_initial = 24'h102061;
            8'hFD: y_initial = 24'h101837;
            8'hFE: y_initial = 24'h101018;
            8'hFF: y_initial = 24'h100806;
            default: y_initial = 24'h400000;
        endcase
    end
    // --- 2. FSM NEWTON-RAPHSON ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; done <= 0; y_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        u_reg <= u_in;
                        state <= CALC_1;
                    end
                end

                CALC_1: begin
                    // y0^2 (Q2.22 * Q2.22 = Q4.44)
                    y0_sq_q44 <= $signed({1'b0, y_initial}) * $signed({1'b0, y_initial});
                    state <= CALC_2;
                end

                CALC_2: begin
                    // u * y0^2 (Qxx.26 * Q4.44 = Qxx.70)
                    u_y2_q70 <= $signed({1'b0, u_reg}) * y0_sq_q44;
                    state <= CALC_3;
                end

                CALC_3: begin
                    // diff = 3.0 - (u * y0^2). D?ch 48 bit t? Q70 v? Q22.
                    diff_q22 <= CONST_3_Q22 - $signed(u_y2_q70[103:48]);
                    state <= CALC_4;
                end

                CALC_4: begin
                    // prod = y0 * diff (Q2.22 * Q22 = Q44)
                    if (diff_q22[31]) // An toàn n?u u quá l?n
                        prod_final_q44 <= {1'b0, y_initial, 23'd0};
                    else
                        prod_final_q44 <= $signed({1'b0, y_initial}) * diff_q22;
                    state <= FINISH;
                end

                FINISH: begin
                    // y_next = 0.5 * prod (Q44 -> d?ch 23 bit -> Q22)
                    // Ki?m tra bão hòa n?u k?t qu? v??t quá d?i Q2.22 (l?n h?n 3.999)
                    if (prod_final_q44[63:47] != 0) 
                        y_out <= 24'hFFFFFF;
                    else
                        y_out <= prod_final_q44[46:23]; 

                    done  <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule




