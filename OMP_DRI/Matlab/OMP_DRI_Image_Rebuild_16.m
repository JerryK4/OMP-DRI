%% RECONSTRUCTION SCRIPT, PSNR COMPARISON AND DRI DISPLAY
clc; clear; close all;

% =========================================================================
% 1. CREATE ORIGINAL IMAGE (GROUND TRUTH) FOR COMPARISON
% =========================================================================
N_side = 16;
x_gt_2d = zeros(N_side, N_side);

x_gt_2d(4, 4) = 1.0;         % Bright isolated point
x_gt_2d(4, 5) = 0.6; x_gt_2d(5, 4) = 0.6; % Blur / transition zone
x_gt_2d(12:13, 12:13) = 0.8;
x_gt_2d(8, 8) = 0.9;         % Center point
x_gt_2d(7, 8) = 0.5; x_gt_2d(9, 8) = 0.5;
x_gt_2d(8, 7) = 0.5; x_gt_2d(8, 9) = 0.5;

% =========================================================================
% 2. READ DATA FROM FPGA FILE
% =========================================================================
filename = 'omp_dri_progressive_results.txt';
if ~exist(filename, 'file')
    error(['[ERROR] File "', filename, '" not found.']);
end

vec_4x4   = zeros(4*4, 1);
vec_8x8   = zeros(8*8, 1);
vec_16x16 = zeros(16*16, 1);
current_res = 0; 

fid = fopen(filename, 'r');
fprintf('Parsing DRI data from Vivado Simulation...\n');

while ~feof(fid)
    line_str = fgetl(fid);
    if isempty(line_str) || ~ischar(line_str)
        continue;
    end
    
    if ~isempty(strfind(line_str, '4x4'))
        current_res = 4;
    elseif ~isempty(strfind(line_str, '8x8'))
        current_res = 8;
    elseif ~isempty(strfind(line_str, '16x16'))
        current_res = 16;
    end
    
    % Regex to extract Lambda and Val
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
% 3. IMAGE RECONSTRUCTION (Fix Transpose & Negative Noise Filtering)
% =========================================================================
% Transpose symbol is kept intact to match FPGA Row-major ordering
img_4x4   = reshape(vec_4x4,   [4, 4]);
img_8x8   = reshape(vec_8x8,   [8, 8]);
img_16x16 = reshape(vec_16x16, [16, 16]);

% =========================================================================
% 4. PSNR CALCULATION (imresize nearest interpolation is USED FOR COMPUTATION ONLY)
% =========================================================================
calc_psnr = @(recon, ref) 10 * log10((1.0^2) / (mean((ref(:) - recon(:)).^2) + eps));

% Calculate PSNR
psnr_16 = calc_psnr(img_16x16, x_gt_2d);

fprintf('PSNR 16x16: %.2f dB\n', psnr_16);

% =========================================================================
% 5. DISPLAY (Direct Matrix Plotting + Gamma Correction)
% =========================================================================
% Brightness scaling for 4x4
img_4x4_disp = img_4x4;
max_4 = max(img_4x4_disp(:));
if max_4 > 0, img_4x4_disp = (img_4x4_disp / max_4) .^ 2.0; end

% Brightness scaling for 8x8
img_8x8_disp = img_8x8;
max_8 = max(img_8x8_disp(:));
if max_8 > 0, img_8x8_disp = (img_8x8_disp / max_8) .^ 2.0; end

% 16x16 remains unchanged
img_16x16_disp = img_16x16; 

% Start plotting
figure('Name', 'FPGA OMP-DRI Reconstruction', 'Color', 'w', 'Position', [50, 150, 1400, 400]);

% Subplot 1: Ground Truth
subplot(1, 4, 1);
imagesc(x_gt_2d); axis image; colormap gray; 
title('Original Image (16x16)', 'FontWeight', 'bold');
xlabel('Ground Truth');

% Subplot 2: Level 1 (4x4) - DIRECT 4x4 MATRIX PLOTTING
subplot(1, 4, 2);
imagesc(img_4x4_disp); axis image; colormap gray; 
title('Level 1 (4x4)');
xlabel(sprintf('PSNR: N/A')); 

% Subplot 3: Level 2 (8x8) - DIRECT 8x8 MATRIX PLOTTING
subplot(1, 4, 3);
imagesc(img_8x8_disp); axis image; colormap gray; 
title('Level 2 (8x8)');
xlabel(sprintf('PSNR: N/A')); 

% Subplot 4: Level 3 (16x16)
subplot(1, 4, 4);
imagesc(img_16x16_disp); axis image; colormap gray; 
title('Level 3 (16x16)');
xlabel(sprintf('PSNR: %.2f dB', psnr_16));

% Super title for the entire Figure window
annotation('textbox', [0.35, 0.9, 0.3, 0.1], ...
    'String', 'DRI RESULTS FROM SIMULATION', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');