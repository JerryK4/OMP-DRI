%% SCRIPT GHÉP 4 KH?I 16x16 THÀNH ?NH 32x32 VÀ SO SÁNH PSNR
clc; clear; close all;

% =========================================================================
% 1. T?O ?NH G?C (GROUND TRUTH) 32x32 ?? ??I CHI?U
% (S? d?ng m?u Nested Squares t?i gi?n b?n ?ã dùng ? b??c tr??c)
% =========================================================================
N_side = 32;
img_gt = zeros(N_side, N_side);

% Vi?n vuông (11x11)
img_gt(11, 11:21) = 0.6; img_gt(21, 11:21) = 0.6;
img_gt(11:21, 11) = 0.6; img_gt(11:21, 21) = 0.6;
% 4 ??nh kim c??ng
img_gt(11, 16) = 0.9; img_gt(21, 16) = 0.9;
img_gt(16, 11) = 0.9; img_gt(16, 21) = 0.9;
% Kh?i vuông tâm 2x2
img_gt(15:16, 15:16) = 1.0; 

% =========================================================================
% 2. C?U HÌNH ??A CHÍ GHÉP KH?I (TILING MAP)
% Gi? s? th? t? ch?y: 1 (Trên-Trái), 2 (Trên-Ph?i), 3 (D??i-Trái), 4 (D??i-Ph?i)
% =========================================================================
tile_offsets = [
    1,  1;   % Tile 1: Hàng 1-16, C?t 1-16
    1, 17;   % Tile 2: Hàng 1-16, C?t 17-32
    17, 1;   % Tile 3: Hàng 17-32, C?t 1-16
    17, 17   % Tile 4: Hàng 17-32, C?t 17-32
];

img_recon = zeros(N_side, N_side);

% =========================================================================
% 3. ??C D? LI?U T? 4 FILE .TXT
% =========================================================================
for t = 1:4
    filename = sprintf('omp_reconstruction_results_%d.txt', t);
    if ~exist(filename, 'file')
        warning('Khong tim thay file %s', filename);
        continue;
    end
    
    fprintf('Dang doc %s...\n', filename);
    fid = fopen(filename, 'r');
    
    % T?o ma tr?n t?m cho kh?i 16x16
    sub_img_vec = zeros(16*16, 1);
    
    % ??c t?ng dòng
    while ~feof(fid)
        line = fgetl(fid);
        % Regex trích xu?t Lambda và Val (Float)
        % Format: Index | Lambda | Hex | Float
        tokens = regexp(line, '^\s*\d+\s*\|\s*(\d+)\s*\|\s*[0-9a-fA-F]+\s*\|\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        
        if ~isempty(tokens)
            lambda = str2double(tokens{1}{1});
            val    = str2double(tokens{1}{2});
            
            % Gán giá tr? vào ?úng v? trí trong vector 256 ph?n t?
            % (C?ng 1 vì MATLAB index t? 1)
            if lambda < 256
                sub_img_vec(lambda + 1) = val;
            end
        end
    end
    fclose(fid);
    
    % Chuy?n kh?i 1D v? 2D 16x16
    % L?u ý: reshape theo [16,16] vì ?nh ???c vector hóa theo c?t trong OMP
    sub_img_2d = reshape(sub_img_vec, [16, 16]);
    
    % Ghép kh?i vào ?nh t?ng 32x32
    row_start = tile_offsets(t, 1);
    col_start = tile_offsets(t, 2);
    img_recon(row_start : row_start+15, col_start : col_start+15) = sub_img_2d;
end

% L?c nhi?u âm (do tính toán fixed-point)
img_recon = max(0, img_recon);

% =========================================================================
% 4. TÍNH TOÁN PSNR VÀ HI?N TH?
% =========================================================================
mse = mean((img_gt(:) - img_recon(:)).^2);
if mse > 0
    psnr_val = 10 * log10(1.0 / mse);
else
    psnr_val = Inf;
end

fprintf('\n>>> PSNR giua anh goc va anh ghep tu FPGA: %.2f dB\n', psnr_val);

% Hi?n th?
figure('Color', 'w', 'Position', [100, 100, 900, 400]);

subplot(1, 2, 1);
imagesc(img_gt); colormap gray; axis image;
title('Anh Goc (Ground Truth) 32x32');
xlabel('Kich thuoc thuc');

subplot(1, 2, 2);
imagesc(img_recon); colormap gray; axis image;
title(['Anh Phuc Hoi tu FPGA (Tiling)', char(10), 'PSNR = ', num2str(psnr_val), ' dB']);
xlabel('Ghep tu 4 khoi 16x16');

% V? ???ng k? phân tách 4 kh?i ?? d? quan sát
hold on;
line([16.5, 16.5], [0.5, 32.5], 'Color', 'r', 'LineStyle', '--');
line([0.5, 32.5], [16.5, 16.5], 'Color', 'r', 'LineStyle', '--');