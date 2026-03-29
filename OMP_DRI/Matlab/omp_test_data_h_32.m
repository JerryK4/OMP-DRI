%% GOM D? LI?U BCS VÀO FILE HEADER C (.h)
clc; clear;

file_out_h = 'omp_bcs_data.h';
fid_out = fopen(file_out_h, 'w');

fprintf(fid_out, '#ifndef OMP_BCS_DATA_H\n#define OMP_BCS_DATA_H\n#include "xil_types.h"\n\n');

% Hàm ph? tr? ghi m?ng
write_array = @(txt_file, arr_name) ...
    fprintf(fid_out, 'u32 %s[%d] __attribute__((aligned(32))) = {\n%s\n};\n\n', ...
    arr_name, length(importdata(txt_file)), ...
    sprintf('    0x%s,', string(importdata(txt_file))));

% Ghi Ma tr?n Phi (1 l?n)
write_array('phi_k16.txt', 'phi_data');

% Ghi 4 vector Y cho 4 kh?i
write_array('y_block1.txt', 'y_data_1');
write_array('y_block2.txt', 'y_data_2');
write_array('y_block3.txt', 'y_data_3');
write_array('y_block4.txt', 'y_data_4');

fprintf(fid_out, '#endif // OMP_BCS_DATA_H\n');
fclose(fid_out);
disp('>>> ?ã t?o file omp_bcs_data.h thành công!');