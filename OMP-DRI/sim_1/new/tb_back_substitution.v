`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/23/2026 08:24:34 PM
// Design Name: 
// Module Name: tb_back_substitution
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


module tb_back_substitution();

    // --- Control Signals ---
    reg clk;
    reg rst_n;
    reg start_bsub;
    reg [4:0] K_final;
    
    // Interface with calc_b_vector module
    reg [3:0]  b_idx_in;
    reg [23:0] b_val_in;
    reg        b_we_in;

    // Interface with BRAM U (Mock)
    wire [5:0]  u_addr;
    reg  [95:0] u_rdata;

    // Output results
    wire [3:0]  x_idx;
    wire [23:0] x_val;
    wire        x_we;
    wire        done_bsub;

    // --- Unit Under Test (UUT) Connection ---
    back_substitution uut (
        .clk(clk), 
        .rst_n(rst_n), 
        .start_bsub(start_bsub), 
        .K_final(K_final),
        .b_idx_in(b_idx_in), 
        .b_val_in(b_val_in), 
        .b_we_in(b_we_in),
        .u_addr(u_addr), 
        .u_rdata(u_rdata),
        .x_idx(x_idx), 
        .x_val(x_val), 
        .x_we(x_we),
        .done_bsub(done_bsub)
    );

    // --- Clock Generation (50MHz) ---
    always #10 clk = ~clk;

    // --- Mock BRAM U Data (1-cycle delay) ---
    always @(posedge clk) begin
        case (u_addr)
            // Column 0: U[0,0]=2.0
            6'd0: u_rdata <= {24'h0, 24'h0, 24'h0, 24'h004000};
            // Column 1: U[0,1]=1.0, U[1,1]=3.0
            6'd4: u_rdata <= {24'h0, 24'h0, 24'h006000, 24'h002000};
            // Column 2: U[0,2]=1.0, U[1,2]=2.0, U[2,2]=4.0
            6'd8: u_rdata <= {24'h0, 24'h008000, 24'h004000, 24'h002000};
            default: u_rdata <= 96'h0;
        endcase
    end

    // --- Test Procedure ---
    initial begin
        // Initialization
        clk = 0; rst_n = 0; start_bsub = 0; K_final = 3;
        b_idx_in = 0; b_val_in = 0; b_we_in = 0;
        #100 rst_n = 1; #40;

        // STEP 1: Load b-vector = [9, 16, 8]
        $display(">>> Step 1: Storing b-vector");
        load_b(0, 24'h012000); // b[0] = 9.0
        load_b(1, 24'h020000); // b[1] = 16.0
        load_b(2, 24'h010000); // b[2] = 8.0
        
        #50;
        // STEP 2: Start Back Substitution
        $display(">>> Step 2: Starting Back Substitution");
        start_bsub = 1; #20; start_bsub = 0;

        // Wait for result
        wait(done_bsub);
        #100;
        $display(">>> Simulation Finished!");
        $stop;
    end

    // --- Task to load b-vector (Fixed syntax) ---
    task load_b(input [3:0] idx, input [23:0] val);
    begin
        b_idx_in = idx; 
        b_val_in = val; 
        b_we_in = 1; 
        #20;
        b_we_in = 0; 
        #20;
    end
    endtask

    // --- Monitor Output x_hat ---
    always @(posedge clk) begin
        if (x_we) begin
            $display("Time: %t | x[%d] = %h", $time, x_idx, x_val);
        end
    end

endmodule