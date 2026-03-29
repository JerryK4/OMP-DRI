%% SCRIPT PH?C H?I, SO SÁNH PSNR VÀ HI?N TH? DRI (T??NG THÍCH M?I B?N MATLAB)
clc; clear; close all;

% =========================================================================
% 1. T?O ?NH G?C (GROUND TRUTH) ?? SO SÁNH
% =========================================================================
N_side = 16;
x_gt_2d = zeros(N_side, N_side);

x_gt_2d(4, 4) = 1.0;         
x_gt_2d(4, 5) = 0.6; x_gt_2d(5, 4) = 0.6; 
x_gt_2d(12:13, 12:13) = 0.8; 
x_gt_2d(8, 8) = 0.9;         
x_gt_2d(7, 8) = 0.5; x_gt_2d(9, 8) = 0.5;
x_gt_2d(8, 7) = 0.5; x_gt_2d(8, 9) = 0.5;
    

% =========================================================================
% 2. ??C D? LI?U T? FILE FPGA
% =========================================================================
filename = 'omp_dri_progressive_results.txt';
if ~exist(filename, 'file')
    error(['[L?I] Không tìm th?y file "', filename, '".']);
end

vec_4x4   = zeros(4*4, 1);
vec_8x8   = zeros(8*8, 1);
vec_16x16 = zeros(16*16, 1);
current_res = 0; 

fid = fopen(filename, 'r');
fprintf('?ang phân tích d? li?u DRI t? FPGA...\n');

while ~feof(fid)
    line_str = fgetl(fid);
    if isempty(line_str) || ~ischar(line_str)
        continue;
    end
    
    % --- S?A L?I: Thay contains b?ng strfind ?? t??ng thích b?n c? ---
    if ~isempty(strfind(line_str, '4x4'))
        current_res = 4;
    elseif ~isempty(strfind(line_str, '8x8'))
        current_res = 8;
    elseif ~isempty(strfind(line_str, '16x16'))
        current_res = 16;
    end
    
    % Regex trích xu?t Lambda và Val
    tokens = regexp(line_str, 'Lambda\s+(\d+)\s+\|\s+Val\s+([-+]?[0-9]*\.?[0-9]+)', 'tokens');
    
    if ~isempty(tokens)
        lambda_idx = str2double(tokens{1}{1});
        pixel_val  = str2double(tokens{1}{2});
        
        if current_res == 4 && (lambda_idx < 16)
            vec_4x4(lambda_idx + 1) = pixel_val;
        elseif current_res == 8 && (lambda_idx < 64)
            vec_8x8(lambda_idx + 1) = pixel_val;
        elseif current_res == 16 && (lambda_idx < 256)
            vec_16x16(lambda_idx + 1) = pixel_val;
        end
    end
end
fclose(fid);

% =========================================================================
% 3. D?NG HÌNH VÀ UPSCALING
% =========================================================================
img_4x4   = max(0, reshape(vec_4x4,   [4, 4]));
img_8x8   = max(0, reshape(vec_8x8,   [8, 8]));
img_16x16 = max(0, reshape(vec_16x16, [16, 16]));

% Phóng to pixelated b?ng Kronecker
img_4x4_up = kron(img_4x4, ones(4, 4)); 
img_8x8_up = kron(img_8x8, ones(2, 2));

% =========================================================================
% 4. TÍNH TOÁN PSNR
% =========================================================================
calc_psnr = @(recon, ref) 10 * log10((1.0^2) / (mean((ref(:) - recon(:)).^2) + eps));

psnr_4  = calc_psnr(img_4x4_up, x_gt_2d);
psnr_8  = calc_psnr(img_8x8_up, x_gt_2d);
psnr_16 = calc_psnr(img_16x16,  x_gt_2d);

fprintf('PSNR 4x4:   %.2f dB\n', psnr_4);
fprintf('PSNR 8x8:   %.2f dB\n', psnr_8);
fprintf('PSNR 16x16: %.2f dB\n', psnr_16);

% =========================================================================
% 5. HI?N TH?
% =========================================================================
figure('Name', 'FPGA OMP-DRI Reconstruction', 'Color', 'w', 'Position',[100, 200, 1300, 400]);

subplot(1, 4, 1);
imagesc(x_gt_2d); colormap gray; axis image; axis off;
title('Ground Truth', 'FontWeight', 'bold');

subplot(1, 4, 2);
imagesc(img_4x4_up); colormap gray; axis image; axis off;
title(sprintf('4x4 (PSNR: %.2f)', psnr_4));

subplot(1, 4, 3);
imagesc(img_8x8_up); colormap gray; axis image; axis off;
title(sprintf('8x8 (PSNR: %.2f)', psnr_8));

subplot(1, 4, 4);
imagesc(img_16x16); colormap gray; axis image; axis off;
title(sprintf('16x16 (PSNR: %.2f)', psnr_16));

%sgtitle (B?n c? không có sgtitle nên ta dùng annotation n?u c?n)
text_obj = annotation('textbox', [0.35, 0.9, 0.3, 0.1], ...
    'String', 'K?T QU? DRI T? FPGA', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');