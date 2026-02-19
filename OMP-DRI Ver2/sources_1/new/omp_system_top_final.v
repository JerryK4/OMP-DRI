`timescale 1ns / 1ps

module omp_system_top_final #
(
    parameter DW         = 24,    // Q10.13
    parameter ADDR_W_PHI = 12,    // 4096 hàng Phi
    parameter COL_W      = 8,     // 256 c?t
    parameter MAX_K      = 16
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire start_system,     
    
    // --- Interface Outstream ---
    output wire [23:0] x_hat_val,
    output wire [3:0]  x_hat_idx,
    output wire        x_hat_valid,
    output wire        done_all_system,

    // --- Debug Port ---
    output wire [7:0]  monitor_lambda,
    output wire [4:0]  monitor_iteration
);

    // =====================================================
    // 1. KHAI BÁO TÍN HI?U VÀ TR?NG THÁI FSM
    // =====================================================
    localparam IDLE      = 2'd0,
               RUN_CORE  = 2'd1, 
               RUN_EST   = 2'd2, 
               FINISH    = 2'd3;

    reg [1:0] state;
    reg start_core_reg, start_est_reg;
    
    wire done_core, done_est;
    wire [COL_W-1:0] last_lambda_bus;
    wire [4:0]       current_i_bus;

    // --- Wires ?i?u ph?i BRAM ---
    wire [ADDR_W_PHI-1:0] phi_mem_addr;
    wire [95:0]           phi_mem_dout;
    
    wire [3:0]  y_mem_addr, y_addr_core, y_addr_est;
    wire [95:0] y_mem_dout;
    
    wire [7:0]  q_mem_addr_a, q_mem_addr_b, q_addr_core_a, q_addr_core_b, q_addr_est_b;
    wire        q_mem_we_a, q_we_core;
    wire [95:0] q_mem_din_a, q_din_core, q_mem_dout_b;
    
    wire [7:0]  r_mem_addr_a, r_mem_addr_b, r_addr_core_a, r_addr_est_b;
    wire        r_mem_we_a, r_we_core;
    wire [23:0] r_mem_din_a, r_din_core, r_mem_dout_b;

    assign monitor_lambda    = last_lambda_bus;
    assign monitor_iteration = current_i_bus;

    /* ==========================================================
       2. LOGIC PHÂN QUY?N TRUY C?P B? NH? (Arbitration)
    ========================================================== */
    // PHI BRAM: Ch? kh?i Core dùng (Atom Selection & QR)
    wire [ADDR_W_PHI-1:0] phi_addr_core;
    assign phi_mem_addr = phi_addr_core; 
    

    // Y BRAM: Core dùng lúc INIT, Est dùng lúc tính v = Q'y
    assign y_mem_addr = (state == RUN_EST) ? y_addr_est : y_addr_core;

    // Q BRAM Port A: Ch? kh?i Core ghi
    assign q_mem_addr_a = q_addr_core_a;
    assign q_mem_we_a   = q_we_core;
    assign q_mem_din_a  = q_din_core;
    
    // Q BRAM Port B (??c): Mux gi?a Core (Update Resid) và Est (v-calc)
    assign q_mem_addr_b = (state == RUN_EST) ? q_addr_est_b : q_addr_core_b;

    // R BRAM Port A (Ghi): Ch? kh?i Core ghi các h? s? Rji, Rii
    assign r_mem_addr_a = r_addr_core_a;
    assign r_mem_we_a   = r_we_core;
    assign r_mem_din_a  = r_din_core;
    
    // R BRAM Port B (??c): Ch? kh?i Est dùng ?? gi?i Back-substitution
    assign r_mem_addr_b = r_addr_est_b;

    /* ==========================================================
       3. INSTANTIATE CÁC KH?I CH?C N?NG (Core & Estimation)
    ========================================================== */

    // KH?I 1: VÒNG L?P OMP (C?n s?a l?i omp_core_top ?? expose port RAM)
    omp_core_top #(
        .DW(DW), .MAX_K(MAX_K)
    ) u_omp_core (
        .clk(clk), .rst_n(rst_n), 
        .start_omp(start_core_reg),
        .N_cols(8'd255), .M_rows(6'd15), .K_limit(5'd16),
        
        // Giao ti?p BRAM ra ngoài
        .phi_addr(phi_addr_core), .phi_data(phi_mem_dout),
        .y_mem_addr(y_addr_core), .y_mem_dout(y_mem_dout),
        .q_mem_addr_a(q_addr_core_a), .q_mem_we_a(q_we_core), .q_mem_din_a(q_din_core),
        .q_mem_addr_b(q_addr_core_b), .q_mem_dout_b(q_mem_dout_b),
        .r_mem_addr_a(r_addr_core_a), .r_mem_we_a(r_we_core), .r_mem_din_a(r_din_core),
        
        .last_lambda(last_lambda_bus), .current_i(current_i_bus),
        .done_omp_core(done_core)
    );

    // KH?I 2: GI?I MÃ CU?I CÙNG
    final_estimation_top #(
        .DW(DW)
    ) u_final_est (
        .clk(clk), .rst_n(rst_n), .start_est(start_est_reg),
        .y_addr(y_addr_est), .y_dout(y_mem_dout),
        .q_addr(q_addr_est_b), .q_dout(q_mem_dout_b),
        .r_addr(r_addr_est_b), .r_dout(r_mem_dout_b),
        .x_hat_val(x_hat_val), .x_hat_idx(x_hat_idx), .x_hat_valid(x_hat_valid),
        .done_all(done_est)
    );

    /* ==========================================================
       4. MASTER FSM
    ========================================================== */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_core_reg <= 0;
            start_est_reg  <= 0;
        end else begin
            start_core_reg <= 0;
            start_est_reg  <= 0;

            case (state)
                IDLE: if (start_system) begin
                    state <= RUN_CORE;
                    start_core_reg <= 1'b1;
                end

                RUN_CORE: if (done_core) begin
                    state <= RUN_EST;
                    start_est_reg <= 1'b1;
                end

                RUN_EST: if (done_est) state <= FINISH;

                FINISH: if (!start_system) state <= IDLE;
                
                default: state <= IDLE;
            endcase
        end
    end

    assign done_all_system = (state == FINISH);

    /* ==========================================================
       5. V?T LÝ HÓA CÁC BRAM (IP Cores)
    ========================================================== */
    phi_bram u_phi (.clka(clk), .addra(phi_mem_addr), .douta(phi_mem_dout));
    y_bram   u_y   (.clka(clk), .addra(y_mem_addr),   .douta(y_mem_dout));
    
    q_bram u_q (
        .clka(clk), .wea(q_mem_we_a), .addra(q_mem_addr_a), .dina(q_mem_din_a), // Port A: Write
        .clkb(clk), .web(1'b0),        .addrb(q_mem_addr_b), .dinb(96'b0),    .doutb(q_mem_dout_b) // Port B: Read
    );

    r_bram u_r (
        .clka(clk), .wea(r_mem_we_a), .addra(r_mem_addr_a), .dina(r_mem_din_a), // Port A: Write
        .clkb(clk), .web(1'b0),        .addrb(r_mem_addr_b), .dinb(24'b0),    .doutb(r_mem_dout_b) // Port B: Read
    );

endmodule