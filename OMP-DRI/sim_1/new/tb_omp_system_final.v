`timescale 1ns / 1ps

module tb_omp_system_top();

    // --- 1. Tín hi?u ?i?u khi?n ---
    reg clk;
    reg rst_n;
    reg start_system;
    
    // Tham s? c?u hình cho ?nh 8x8
    reg [5:0] N_in;    // 63
    reg [2:0] M_in;    // 7
    reg [4:0] K_limit; // 16

    // --- 2. Tín hi?u ??u ra ---
    wire [23:0] pixel_val;
    wire [5:0]  pixel_addr;
    wire        pixel_we;
    wire        done_all;

    // --- 3. K?t n?i Module Top System (T??ng minh) ---
    omp_system_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_system(start_system),
        .N_in(N_in),
        .M_in(M_in),
        .K_limit(K_limit),
        .pixel_val(pixel_val),
        .pixel_addr(pixel_addr),
        .pixel_we(pixel_we),
        .done_all(done_all)
    );

    // --- 4. T?o xung Clock 50MHz (Chu k? 20ns) ---
    always #10 clk = ~clk;

    // --- 5. Logic ghi d? li?u Pixel ra File ?? v? ?nh ---
    integer file_ptr;
    initial begin
        // File này s? ???c t?o trong th? m?c simulation c?a project
        file_ptr = $fopen("reconstructed_image_data.txt", "w");
        if (file_ptr == 0) begin
            $display("ERROR: Khong the tao file output!");
            $finish;
        end
    end

    // M?i khi có pixel_we = 1, ghi ??a ch? và giá tr? vào file
    always @(posedge clk) begin
        if (pixel_we) begin
            $fdisplay(file_ptr, "%d %h", pixel_addr, pixel_val);
            // In ra Console ?? theo dõi th?i gian th?c
            if (pixel_val !== 24'd0)
                $display("Time: %t | Captured Pixel %d | Value: %h (Sparse)", $time, pixel_addr, pixel_val);
            else
                $display("Time: %t | Captured Pixel %d | Value: 000000", $time, pixel_addr);
                  
        end
    end

    // --- 6. K?ch b?n mô ph?ng toàn di?n ---
    initial begin
        // Kh?i t?o tr?ng thái ban ??u
        clk = 0;
        rst_n = 0;
        start_system = 0;
        
        // Thi?t l?p ch?y ?nh 8x8 th?c t?
        N_in = 6'd63;    
        M_in = 3'd7;     
        K_limit = 5'd8; 

        // Nh? Reset
        #100 rst_n = 1;
        #100;

        $display("-----------------------------------------------------");
        $display(">>> OMP SYSTEM START: FULL RECONSTRUCTION PROCESS");
        $display("-----------------------------------------------------");

        // Kích ho?t nút b?m Start
        #20 start_system = 1;
        #20 start_system = 0;

        // ??i h? th?ng ch?y xong
        // Quá trình này tính toán r?t nhi?u nên s? m?t kho?ng 300us - 500us
        wait(done_all);
        
        #500;
        $fclose(file_ptr); // ?óng file
        $display("-----------------------------------------------------");
        $display(">>> OMP SYSTEM DONE: IMAGE RECONSTRUCTED SUCCESSFULLY");
        $display(">>> Result saved to: reconstructed_image_data.txt");
        $display("-----------------------------------------------------");
        
        #100;
        $stop; // D?ng mô ph?ng
    end

endmodule