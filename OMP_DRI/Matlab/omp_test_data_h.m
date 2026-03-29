%% SCRIPT CHUY?N ??I FILE TXT SANG FILE C HEADER (.h) CHO XILINX SDK
function omp_test_data_h()
clc; clear;

% 1. ??nh ngh?a tên file
file_phi_txt = 'lv3_16x16_phi.txt';
file_y_txt   = 'lv3_16x16_y.txt';
file_out_h   = 'omp_test_data.h';

% Ki?m tra file t?n t?i
if ~exist(file_phi_txt, 'file') || ~exist(file_y_txt, 'file')
    error('Không tìm th?y file .txt. Hãy ??m b?o chúng n?m cùng th? m?c!');
end

% 2. M? file Header ?? ghi
fid_out = fopen(file_out_h, 'w');
fprintf('>>> ?ang t?o file %s ...\n', file_out_h);

% Vi?t c?u trúc Header Guard c?a C/C++ ?? ch?ng include nhi?u l?n
fprintf(fid_out, '/* ==========================================================\n');
fprintf(fid_out, ' * FILE D? LI?U ???C T?O T? ??NG T? MATLAB\n');
fprintf(fid_out, ' * Dùng cho Xilinx SDK / Vitis (AXI DMA)\n');
fprintf(fid_out, ' * ========================================================== */\n\n');
fprintf(fid_out, '#ifndef OMP_TEST_DATA_H\n');
fprintf(fid_out, '#define OMP_TEST_DATA_H\n\n');
fprintf(fid_out, '#include "xil_types.h"\n\n'); % Th? vi?n Xilinx ch?a ki?u u32

% 3. G?i hàm ph? tr? ?? x? lý t?ng file
write_to_c_array(file_phi_txt, fid_out, 'phi_data');
write_to_c_array(file_y_txt, fid_out, 'y_data');

% ?óng Header Guard
fprintf(fid_out, '#endif // OMP_TEST_DATA_H\n');
fclose(fid_out);

fprintf('>>> THÀNH CÔNG! ?ã t?o xong file: %s\n', file_out_h);
end

%% --- Hàm ph? tr?: ??c TXT và ghi thành m?ng C ---
function write_to_c_array(txt_filename, fid_out, array_name)
    % ??c file TXT
    fid_in = fopen(txt_filename, 'r');
    data = textscan(fid_in, '%s');
    fclose(fid_in);
    hex_strings = data{1};
    
    num_elements = length(hex_strings);
    
    % Vi?t khai báo m?ng.
    % Thu?c tính __attribute__((aligned(32))) b?t bu?c ph?i có ?? DMA ch?y không b? l?i ranh gi?i RAM
    fprintf(fid_out, '// D? li?u t? file: %s (%d ph?n t?)\n', txt_filename, num_elements);
    fprintf(fid_out, 'u32 %s[%d] __attribute__((aligned(32))) = {\n', array_name, num_elements);
    
    % Ghi d? li?u
    for i = 1:num_elements
        % Thêm ti?n t? 0x cho s? Hex c?a C
        fprintf(fid_out, '    0x%s', hex_strings{i});
        
        % Thêm d?u ph?y n?u ch?a ph?i ph?n t? cu?i
        if i < num_elements
            fprintf(fid_out, ',');
        end
        
        % Xu?ng dòng sau m?i 8 ph?n t? cho code C d? nhìn
        if mod(i, 8) == 0
            fprintf(fid_out, '\n');
        end
    end
    fprintf(fid_out, '\n};\n\n');
end