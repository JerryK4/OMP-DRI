`timescale 1ns / 1ps

module tb_omp_core_ab();

    reg clk, rst_n, start_omp;
    reg [5:0] N_in;
    reg [2:0] M_in;
    reg [4:0] K_limit;

    wire [5:0]  lambda_out;
    wire        lambda_we;
    wire [4:0]  current_i_out;
    wire [4:0]  final_i;
    wire        done_omp;
    
    // Tín hi?u ??c BRAM m? r?ng
    wire [95:0] q_data_ext, y_data_ext, u_data_ext;

    // --- K?T N?I MODULE UUT ---
    omp_core_ab uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_omp(start_omp),
        .N_in(N_in),
        .M_in(M_in),
        .K_limit(K_limit),
        
        // K?t n?i các chân ext ph?c v? Block C
        .q_addr_ext(7'd0),
        .q_data_ext(q_data_ext),
        .y_addr_ext(3'd0),
        .y_data_ext(y_data_ext),
        .u_addr_ext(6'd0),
        .u_data_ext(u_data_ext),
        
        .lambda_out(lambda_out),
        .lambda_we(lambda_we),
        .current_i_out(current_i_out),
        .final_i(final_i),
        .done_omp(done_omp)
    );

    always #10 clk = (clk === 1'b0);

    initial begin
        clk = 0; rst_n = 0; start_omp = 0;
        N_in = 6'd63; M_in = 3'd7; K_limit = 5'd16;

        #200 rst_n = 1; #100;
        #20 start_omp = 1; #20 start_omp = 0;

        // Ch? ??n khi done_omp lên 1
        wait(done_omp === 1'b1);
        #500;
        $display(">>> [SIM] OMP Core AB SUCCESS!");
        $stop;
    end

    // Monitor k?t qu? Lambda
    always @(posedge clk) begin
        if (lambda_we) begin
            $display("Time: %t | Iteration: %d | FOUND LAMBDA: %d", $time, current_i_out, lambda_out);
        end
    end

endmodule