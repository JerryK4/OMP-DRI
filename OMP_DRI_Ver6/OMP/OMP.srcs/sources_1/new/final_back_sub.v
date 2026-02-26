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