function OMP_DRI_Full_System_With_PSNR
    clear; clc; close all;

    % 1. SYSTEM CONFIGURATION (Fixed-point 24-bit: Q11.13)
    cfg.BW = 24;                
    cfg.FW = 13;                
    cfg.Levels = [4, 8, 16];    
    cfg.M_list = [8, 16, 64];   
    cfg.K_list = [4, 6, 16];    

    % 2. GENERATE ORIGINAL SUPER-SPARSE GRAYSCALE IMAGE 16x16 (Cyber-Cross Pattern - Exactly 16 Pixels)
    img_gt = zeros(16, 16);

    img_gt(4, 4) = 1.0;         % Bright isolated point
    img_gt(4, 5) = 0.6; img_gt(5, 4) = 0.6; % Blur / transition zone
    
    img_gt(12:13, 12:13) = 0.8;
    
    img_gt(8, 8) = 0.9;         % Center point
    img_gt(7, 8) = 0.5; img_gt(9, 8) = 0.5;
    img_gt(8, 7) = 0.5; img_gt(8, 9) = 0.5;

    x_gt_full = img_gt(:);

    % 3. GENERATE MEASUREMENT DATA (DRI Measurement Reuse)
    t_setup_start = tic;
    rng('shuffle'); 
    Phi_max = randn(max(cfg.M_list), 16*16);
    for j = 1:size(Phi_max, 2)
        Phi_max(:,j) = Phi_max(:,j) / norm(Phi_max(:,j));
    end
    y_full = Phi_max * x_gt_full; 
    t_setup_ms = toc(t_setup_start) * 1000;

    % 4. DISPLAY AND EXECUTE DRI
    fprintf('--- STARTING OMP-DRI PROCESS, PSNR & TIMING ANALYSIS ---\n');
    fprintf('%-10s | %-10s | %-10s | %-10s | %-10s\n', 'Level', 'Resolution', 'M (Meas)', 'PSNR (dB)', 'Time (ms)');
    fprintf('----------------------------------------------------------------------------\n');
    
    figure('Color', 'w', 'Name', 'OMP-DRI Analysis: PSNR & Timing', 'Position', [100, 300, 1400, 380]);
    
    % Subplot 1: Original Image
    subplot(1, 4, 1);
    imagesc(img_gt); colormap gray; axis image;
    title('Original Image (16x16)');
    xlabel('Ground Truth');

    % Variable to store total execution time
    total_time_ms = 0;

    for lv = 1:length(cfg.Levels)
        % --- START ALGORITHM TIMING ---
        t_start = tic; 
        
        n = cfg.Levels(lv);
        M = cfg.M_list(lv);
        K = cfg.K_list(lv);
        N = n^2;

        % Matrix and measurement vector cropping (DRI Reuse)
        Phi_lv = Phi_max(1:M, 1:N);
        y_lv = y_full(1:M);

        % OMP Core Algorithm
        [x_hat, Lambda, Debug] = OMP_Algorithm_Core(Phi_lv, y_lv, K);
        
        t_elapsed_ms = toc(t_start) * 1000; % Convert to milliseconds
        total_time_ms = total_time_ms + t_elapsed_ms;
        % --- END ALGORITHM TIMING ---

        img_rec = reshape(x_hat, [n, n]);

        % --- PSNR CALCULATION (Only for 16x16) ---
        if n == 16
            mse_val = mean((img_gt(:) - img_rec(:)).^2);
            t_elapsed_ms = t_elapsed_ms + t_setup_ms;
            if mse_val > 0
                psnr_val = 10 * log10(1 / mse_val);
            else
                psnr_val = Inf;
            end
            % Format PSNR string
            psnr_str = [num2str(psnr_val, '%.2f'), ' dB'];
            psnr_log = num2str(psnr_val, '%.2f');
        else
            psnr_val = NaN; % Skip calculation
            psnr_str = 'N/A';
            psnr_log = 'N/A';
        end

        % Print results to Command Window
        fprintf('Level %-5d | %-2dx%-7d | %-11d | %-10s | %-10.4f\n', ...
                lv, n, n, M, psnr_log, t_elapsed_ms);

        % --- IMAGE PROCESSING FOR DISPLAY ONLY (Does not affect PSNR) ---
        img_display = img_rec; 
        
        % Apply brightness scaling filter for 4x4 and 8x8 levels only
        if n == 4 || n == 8
            max_val = max(img_display(:));
            if max_val > 0
                % Step 1: Contrast stretching (Scale brightest pixel to White 1.0)
                img_display = img_display / max_val;
                
                % Step 2: Darken gray background using Gamma Correction (Gamma > 1)
                % Power of 2.0 heavily bops gray colors (< 0.5) down to black
                % while preserving White (1.0) as 1.0
                img_display = img_display .^ 2.0; 
            end
        end
        
        % Display reconstructed image
        subplot(1, 4, lv + 1);
        imagesc(img_display); 
        axis image;
        title(sprintf('Level %d (%dx%d)', lv, n, n));
        xlabel({['PSNR: ', psnr_str], ...
                ['Time: ', num2str(t_elapsed_ms, '%.2f'), ' ms']});

        % --- EXPORT FILES (COE & LOG) ---
        prefix = sprintf('lv%d_%dx%d_', lv, n, n);
        export_to_hex_24bit([prefix, 'phi.txt'], Phi_lv(:), cfg.BW, cfg.FW);
        export_to_hex_24bit([prefix, 'y.txt'], y_lv, cfg.BW, cfg.FW);
        txt_to_coe_96bit([prefix, 'phi.txt'], [prefix, 'phi.coe']);
        txt_to_coe_96bit([prefix, 'y.txt'],   [prefix, 'y.coe']);
        save_debug_log([prefix, 'omp_golden_debug.txt'], Debug, cfg.BW, cfg.FW);
        
        % AUTOMATICALLY GENERATE .h FILE WHEN RUNNING THE FINAL LEVEL (16x16)
        if n == 16
            export_c_header('omp_test_data.h', Phi_lv(:), y_lv, cfg.BW, cfg.FW);
        end
    end
    total_time_ms = total_time_ms + t_setup_ms;
    fprintf('----------------------------------------------------------------------------\n');
    fprintf('TOTAL ALGORITHM RUNTIME: %.4f ms\n', total_time_ms);
end

%% --- OMP CORE ALGORITHM (QR/MGS) ---
function [x_hat, Lambda, Debug] = OMP_Algorithm_Core(Phi, y, K)
    [M, N] = size(Phi);
    Lambda = []; res = y;
    Q = zeros(M, K); R = zeros(K, K);
    Debug = struct('lambda', {}, 'u', {}, 'alpha', {}, 'R_col', {});
    for i = 1:K
        proj = Phi' * res;
        [~, pos] = max(abs(proj));
        if ismember(pos, Lambda), break; end
        Lambda = [Lambda, pos];
        w = Phi(:, pos);
        for j = 1:i-1
            R(j, i) = Q(:, j)' * w;
            w = w - R(j, i) * Q(:, j);
        end
        u = sum(w.^2); R(i, i) = sqrt(u); Q(:, i) = w / R(i, i);
        alpha = Q(:, i)' * y; res = res - alpha * Q(:, i);
        Debug(i).lambda = pos - 1;
        Debug(i).u = u;
        Debug(i).alpha = alpha;
        Debug(i).R_col = R(1:i, i);
    end
    x_hat = zeros(N, 1);
    if ~isempty(Lambda)
        x_hat(Lambda) = R(1:length(Lambda), 1:length(Lambda)) \ (Q(:, 1:length(Lambda))' * y);
    end
end

%% --- SAVE GOLDEN DEBUG LOG FUNCTION ---
function save_debug_log(filename, Debug, bw, fw)
    fid = fopen(filename, 'w');
    fprintf(fid, '--- OMP GOLDEN DEBUG LOG (Q11.13) ---\n\n');
    for i = 1:length(Debug)
        fprintf(fid, 'ITERATION %d (Lambda: %d)\n', i-1, Debug(i).lambda);
        fprintf(fid, '  Energy u (Q26): %s\n', dec2hex_signed(Debug(i).u * 2^26, 64));
        fprintf(fid, '  Rii (ISR Q2.22): %s\n', dec2hex_signed(1/sqrt(Debug(i).u) * 2^22, 24));
        fprintf(fid, '  Alpha (Q11.13):  %s\n', dec2hex_signed(Debug(i).alpha * 2^fw, 24));
        for j = 1:length(Debug(i).R_col)-1
            fprintf(fid, '  R[%d,%d] (Q11.13): %s\n', j-1, i-1, dec2hex_signed(Debug(i).R_col(j) * 2^fw, 24));
        end
        fprintf(fid, '-----------------------------------\n');
    end
    fclose(fid);
end

%% --- EXPORT 96-BIT COE FUNCTION ---
function txt_to_coe_96bit(input_txt, output_coe)
    if ~exist(input_txt, 'file'), return; end
    fid_in = fopen(input_txt, 'r');
    raw_data = textscan(fid_in, '%s');
    fclose(fid_in);
    raw_hex = raw_data{1};
    remainder = mod(length(raw_hex), 4);
    if remainder ~= 0
        for k = 1:(4 - remainder), raw_hex{end+1} = '000000'; end
    end
    fid_out = fopen(output_coe, 'w');
    fprintf(fid_out, 'memory_initialization_radix=16;\nmemory_initialization_vector=\n');
    for i = 1:4:length(raw_hex)
        h1 = pad_hex(raw_hex{i}, 6);
        h2 = pad_hex(raw_hex{i+1}, 6);
        h3 = pad_hex(raw_hex{i+2}, 6);
        h4 = pad_hex(raw_hex{i+3}, 6);
        fprintf(fid_out, '%s%s%s%s%s\n', h4, h3, h2, h1, (i+4>length(raw_hex))*';' + (~(i+4>length(raw_hex)))*',');
    end
    fclose(fid_out);
end

%% --- AUXILIARY FUNCTIONS ---
function export_to_hex_24bit(filename, data, bw, fw)
    fid = fopen(filename, 'w');
    scale = 2^fw;
    for i = 1:length(data)
        val = round(data(i) * scale);
        if val < 0, val = 2^bw + val; end
        fprintf(fid, '%06X\n', val);
    end
    fclose(fid);
end

function h = dec2hex_signed(val, bits)
    val = round(val);
    if val < 0, val = 2^bits + val; end
    h = dec2hex(val, bits/4);
end

function s_out = pad_hex(s_in, len)
    if length(s_in) < len, s_out = [repmat('0', 1, len - length(s_in)), s_in];
    else, s_out = s_in(end-len+1:end); end
end

%% --- GENERATE C HEADER FILE DIRECTLY FOR XILINX SDK ---
function export_c_header(filename, Phi_data, y_data, bw, fw)
    fid = fopen(filename, 'w');
    scale = 2^fw;
    
    fprintf(fid, '/* ==========================================================\n');
    fprintf(fid, ' * DATA FILE AUTOMATICALLY GENERATED FROM MATLAB\n');
    fprintf(fid, ' * Used for Xilinx SDK / Vitis (AXI DMA)\n');
    fprintf(fid, ' * ========================================================== */\n\n');
    
    fprintf(fid, '#ifndef OMP_TEST_DATA_H\n#define OMP_TEST_DATA_H\n\n');
    fprintf(fid, '#include "xil_types.h"\n\n');
    
    % Export Phi Matrix
    fprintf(fid, '// Phi Matrix (16384 elements, Fixed-point Q11.13)\n');
    fprintf(fid, 'u32 phi_data[%d] __attribute__((aligned(32))) = {\n', length(Phi_data));
    for i = 1:length(Phi_data)
        val = round(Phi_data(i) * scale);
        if val < 0, val = 2^bw + val; end
        if i == length(Phi_data), fprintf(fid, '    0x%06X\n', val);
        else, fprintf(fid, '    0x%06X, ', val); end
        if mod(i, 8) == 0, fprintf(fid, '\n'); end
    end
    fprintf(fid, '};\n\n');
    
    % Export Vector Y
    fprintf(fid, '// Vector Y (64 elements)\n');
    fprintf(fid, 'u32 y_data[%d] __attribute__((aligned(32))) = {\n', length(y_data));
    for i = 1:length(y_data)
        val = round(y_data(i) * scale);
        if val < 0, val = 2^bw + val; end
        if i == length(y_data), fprintf(fid, '    0x%06X\n', val);
        else, fprintf(fid, '    0x%06X, ', val); end
        if mod(i, 8) == 0, fprintf(fid, '\n'); end
    end
    fprintf(fid, '};\n\n');
    
    fprintf(fid, '#endif // OMP_TEST_DATA_H\n');
    fclose(fid);
end