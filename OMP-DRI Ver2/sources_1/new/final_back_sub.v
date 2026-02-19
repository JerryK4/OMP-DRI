////`timescale 1ns / 1ps

////module final_back_sub #
////(
////    parameter DW = 24,         // Q10.13
////    parameter NUM_K = 16       
////)
////(
////    input wire clk,
////    input wire rst_n,
////    input wire start_bs,
    
////    // ??u vào vector v (768-bit)
////    input wire [767:0] v_in_flat,
    
////    // Giao ti?p r_bram (Read Latency = 1)
////    output reg  [7:0]  r_addr,
////    input  wire [23:0] r_dout,

////    // Output Outstream
////    output reg [23:0] x_hat_val,
////    output reg [3:0]  x_hat_idx,
////    output reg        x_hat_valid,
////    output reg        bs_done
////);

////    // --- FSM States ---
////    localparam IDLE      = 3'd0,
////               SET_ADDR  = 3'd1, // Phát ??a ch? RAM
////               WAIT_RAM  = 3'd2, // ??i 1 nh?p cho BRAM Latency-1
////               SUM_LOOP  = 3'd3, // Tính Sigma(Rij * xj)
////               MULT_ISR  = 3'd4, // x = (v - sum) * ISR
////               OUT_DATA  = 3'd5;

////    reg [2:0] state;
////    reg signed [4:0]  i_idx, j_idx;
////    reg signed [47:0] sum_reg;
////    reg signed [23:0] x_hat_mem [0:15]; 
    
////    // Gi?i mã vector v t? bus ph?ng
////    wire signed [47:0] v_in [0:15];
////    genvar k;
////    generate
////        for (k = 0; k < 16; k = k + 1) begin : unpack_v
////            assign v_in[k] = $signed(v_in_flat[k*48 +: 48]);
////        end
////    endgenerate

////    // --- Logic Gi?i ng??c ---
////    integer m;
////    always @(posedge clk or negedge rst_n) begin
////        if (!rst_n) begin
////            state <= IDLE; bs_done <= 0; x_hat_valid <= 0;
////            r_addr <= 0; sum_reg <= 0; i_idx <= 0; j_idx <= 0;
////            for (m=0; m<16; m=m+1) x_hat_mem[m] <= 24'd0;
////        end else begin
////            case (state)
////                IDLE: begin
////                    bs_done <= 1'b0; x_hat_valid <= 1'b0;
////                    if (start_bs) begin
////                        state <= SET_ADDR;
////                        i_idx <= 5'd15; // OMP gi?i ng??c t? hàng 15 v? 0
////                        j_idx <= 5'd15;
////                        sum_reg <= 48'd0;
////                    end
////                end

////                SET_ADDR: begin
////                    // ??a ch? R(i, j) = (j << 4) + i
////                    r_addr <= (j_idx << 4) + i_idx;
////                    state  <= WAIT_RAM;
////                end

////                WAIT_RAM: begin
////                    // Nh?p này ?? r_dout c?p nh?t d? li?u t? ??a ch? v?a phát
////                    state <= (j_idx == i_idx) ? MULT_ISR : SUM_LOOP;
////                end

////                SUM_LOOP: begin
////                    // sum += R(i,j) * x(j). R(i,j) là Q13, x(j) là Q13 -> d?ch 13
////                    sum_reg <= sum_reg + (($signed(r_dout) * $signed(x_hat_mem[j_idx])) >>> 13);
////                    j_idx   <= j_idx - 1;
////                    state   <= SET_ADDR; // Quay l?i phát ??a ch? cho j ti?p theo
////                end

////                MULT_ISR: begin
////                    // x[i] = (v[i] - sum) * ISR[i]. ISR ? Q2.22
////                    // v_in[i] ? Q26, d?ch 13 ?? v? Q13 kh?p v?i sum_reg
////                    x_hat_mem[i_idx] <= (($signed(v_in[i_idx] >>> 13) - sum_reg[23:0]) * $signed(r_dout)) >>> 22;
                    
////                    if (i_idx == 0) begin
////                        state <= OUT_DATA;
////                        i_idx <= 0;
////                    end else begin
////                        i_idx   <= i_idx - 1;
////                        j_idx   <= 5'd15; // Reset j cho hàng m?i
////                        sum_reg <= 48'd0;
////                        state   <= SET_ADDR;
////                    end
////                end

////                OUT_DATA: begin
////                    x_hat_valid <= 1'b1;
////                    x_hat_idx   <= i_idx[3:0];
////                    x_hat_val   <= x_hat_mem[i_idx];
////                    if (i_idx == 15) begin
////                        bs_done <= 1'b1;
////                        state <= IDLE;
////                    end else i_idx <= i_idx + 1;
////                end

////                default: state <= IDLE;
////            endcase
////        end
////    end
////endmodule


//`timescale 1ns / 1ps

//module final_back_sub #
//(
//    parameter DW = 24         // Q10.13
//)
//(
//    input wire clk,
//    input wire rst_n,
//    input wire start_bs,
    
//    // ??u vào vector v (768-bit)
//    input wire [767:0] v_in_flat,
    
//    // Giao ti?p r_bram (Read Latency = 1)
//    output reg  [7:0]  r_addr,
//    input  wire [23:0] r_dout,

//    // Output Outstream
//    output reg [23:0] x_hat_val,
//    output reg [3:0]  x_hat_idx,
//    output reg        x_hat_valid,
//    output reg        bs_done
//);

//    // --- FSM States ---
//    localparam IDLE      = 3'd0,
//               FETCH_R   = 3'd1, // Phát ??a ch? RAM
//               WAIT_R    = 3'd2, // ??i d? li?u tr? v? t? BRAM
//               CALC      = 3'd3, // Tính toán Sum ho?c ISR
//               OUT_DATA  = 3'd4;

//    reg [2:0] state;
//    reg signed [4:0]  i_idx, j_idx;
//    reg signed [47:0] sum_reg;
//    reg signed [23:0] x_hat_mem [0:15]; 
    
//    // Gi?i mã vector v t? bus ph?ng
//    wire signed [47:0] v_in [0:15];
//    genvar k;
//    generate
//        for (k = 0; k < 16; k = k + 1) begin : unpack_v
//            assign v_in[k] = $signed(v_in_flat[k*48 +: 48]);
//        end
//    endgenerate
//    integer m;
//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            state <= IDLE; bs_done <= 0; x_hat_valid <= 0;
//            r_addr <= 0; sum_reg <= 0; i_idx <= 0; j_idx <= 0;
//            for (m=0; m<16; m=m+1) x_hat_mem[m] <= 24'd0;
//        end else begin
//            case (state)
//                IDLE: begin
//                    bs_done <= 1'b0; x_hat_valid <= 1'b0;
//                    if (start_bs) begin
//                        state <= FETCH_R;
//                        i_idx <= 5'd15; // Gi?i ng??c t? hàng 15 v? 0
//                        j_idx <= 5'd15; // B?t ??u quét t? c?t cu?i
//                        sum_reg <= 48'd0;
//                    end
//                end

//                FETCH_R: begin
//                    // ??a ch? R(i, j) = (j << 4) + i (Do ma tr?n R l?u theo c?t)
//                    r_addr <= (j_idx << 4) + i_idx;
//                    state  <= WAIT_R;
//                end

//                WAIT_R: begin
//                    // Nh?p này ?? r_dout c?p nh?t d? li?u t? RAM
//                    state <= CALC;
//                end

//                CALC: begin
//                    if (j_idx > i_idx) begin
//                        // ?ang tính t?ng Sigma: Rij * xj
//                        sum_reg <= sum_reg + (($signed(r_dout) * $signed(x_hat_mem[j_idx])) >>> 13);
//                        j_idx   <= j_idx - 1;
//                        state   <= FETCH_R; // Quay l?i ??c Rij ti?p theo
//                    end else begin
//                        // ?ang ? v? trí ???ng chéo Rii (Giá tr? ISR)
//                        // x[i] = (v[i] - sum) * ISR[i]
//                        // D?ch v_in t? Q26 v? Q13 ?? tr? sum_reg
//                        x_hat_mem[i_idx] <= (($signed(v_in[i_idx] >>> 13) - sum_reg[23:0]) * $signed(r_dout)) >>> 22;
                        
//                        if (i_idx == 0) begin
//                            state <= OUT_DATA;
//                            i_idx <= 0;
//                        end else begin
//                            // Chuy?n sang hàng i-1
//                            i_idx   <= i_idx - 1;
//                            j_idx   <= 5'd15;
//                            sum_reg <= 48'd0;
//                            state   <= FETCH_R;
//                        end
//                    end
//                end

//                OUT_DATA: begin
//                    x_hat_valid <= 1'b1;
//                    x_hat_idx   <= i_idx[3:0];
//                    x_hat_val   <= x_hat_mem[i_idx];
//                    if (i_idx == 15) begin
//                        bs_done <= 1'b1;
//                        state <= IDLE;
//                    end else i_idx <= i_idx + 1;
//                end

//                default: state <= IDLE;
//            endcase
//        end
//    end
//endmodule


`timescale 1ns / 1ps

module final_back_sub #
(
    parameter DW = 24         // Q10.13
)
(
    input wire clk,
    input wire rst_n,
    input wire start_bs,
    
    input wire [767:0] v_in_flat,
    
    // Giao ti?p r_bram
    output reg  [7:0]  r_addr,
    input  wire [23:0] r_dout,

    // Output Outstream
    output reg [23:0] x_hat_val,
    output reg [3:0]  x_hat_idx,
    output reg        x_hat_valid,
    output reg        bs_done
);

    localparam IDLE      = 3'd0,
               FETCH_R   = 3'd1, 
               WAIT_RAM  = 3'd2, 
               CALC      = 3'd3, 
               OUT_DATA  = 3'd4;

    reg [2:0] state;
    reg signed [4:0]  i_idx, j_idx;
    reg signed [47:0] sum_reg;
    reg signed [23:0] x_hat_mem [0:15]; 
    
    wire signed [47:0] v_in [0:15];
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin : unpack_v
            assign v_in[k] = $signed(v_in_flat[k*48 +: 48]);
        end
    endgenerate
    integer m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; bs_done <= 0; x_hat_valid <= 0;
            r_addr <= 0; sum_reg <= 0; i_idx <= 0; j_idx <= 0;
            for (m=0; m<16; m=m+1) x_hat_mem[m] <= 24'd0;
        end else begin
            case (state)
                IDLE: begin
                    bs_done <= 1'b0; x_hat_valid <= 1'b0;
                    if (start_bs) begin
                        state <= FETCH_R;
                        i_idx <= 5'd15; // Gi?i ng??c t? 15 v? 0
                        j_idx <= 5'd15; 
                        sum_reg <= 48'd0;
                    end
                end

                FETCH_R: begin
                    r_addr <= (j_idx << 4) + i_idx;
                    state  <= WAIT_RAM;
                end

                WAIT_RAM: state <= CALC;

                CALC: begin
                    if (j_idx > i_idx) begin
                        // sum += R[i,j] * x[j]
                        sum_reg <= sum_reg + (($signed(r_dout) * $signed(x_hat_mem[j_idx])) >>> 13);
                        j_idx   <= j_idx - 1;
                        state   <= FETCH_R;
                    end else begin
                        // x[i] = (v[i] - sum) * ISR[i]
                        // S? d?ng toàn b? 48-bit c?a sum_reg ?? tránh m?t bit d?u
                        x_hat_mem[i_idx] <= (($signed(v_in[i_idx] >>> 13) - $signed(sum_reg[36:0])) * $signed(r_dout)) >>> 22;
                        
                        if (i_idx == 0) begin
                            state <= OUT_DATA;
                            i_idx <= 0;
                        end else begin
                            i_idx <= i_idx - 1;
                            j_idx <= 5'd15;
                            sum_reg <= 48'd0;
                            state <= FETCH_R;
                        end
                    end
                end

                OUT_DATA: begin
                    x_hat_valid <= 1'b1;
                    x_hat_idx   <= i_idx[3:0];
                    x_hat_val   <= x_hat_mem[i_idx];
                    if (i_idx == 15) begin
                        bs_done <= 1'b1;
                        state <= IDLE;
                    end else i_idx <= i_idx + 1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule