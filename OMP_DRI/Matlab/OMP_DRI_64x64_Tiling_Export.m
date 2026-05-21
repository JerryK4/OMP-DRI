function OMP_DRI_64x64_Tiling_Individual_Export
    clear; clc; close all;

    % =========================================================================
    % 1. TILING SYSTEM CONFIGURATION (16 blocks of 16x16)
    % =========================================================================
    cfg.BW = 24;               
    cfg.FW = 13;               
    
    N_sub  = 16;               
    M_sub  = 64;               
    K_sub  = 16;               
    N_side = 64;               % Upgrade resolution to 64x64
    num_blocks_per_side = N_side / N_sub; % 64/16 = 4 (Meaning 4x4 = 16 blocks)

    % =========================================================================
    % 2. GENERATE ORIGINAL IMAGE (GROUND TRUTH) 64x64 (Sparse Geometric Pattern)
    % Create a 64x64 image with patterns ensuring sparsity (K < 16) within each block
    % =========================================================================
    img_gt = zeros(N_side, N_side);
    
    % Configuration for U-shape coordinates
    col_left   = 20;  % Left vertical column
    col_right  = 44;  % Right vertical column
    row_top    = 12;  % Start point of U-shape top
    row_bottom = 52;  % Bottom point of U-shape

    % --- 1. Draw two vertical columns (Dotted line for low K sparsity) ---
    % Using a step of 3 pixels to ensure only ~5 pixels exist within every 16-pixel segment
    for r = row_top:3:row_bottom
        % Left column
        img_gt(r, col_left) = 0.9; 
        img_gt(r, col_left+1) = 0.5; % Grayscale anti-aliasing / smoothing effect
        
        % Right column
        img_gt(r, col_right) = 0.9;
        img_gt(r, col_right-1) = 0.5;
    end

    % --- 2. Draw the bottom of the U-shape (Connecting the two columns) ---
    % Draw horizontal dotted lines at row_bottom
    for c = col_left:3:col_right
        img_gt(row_bottom, c) = 0.8;
        img_gt(row_bottom-1, c) = 0.4;
    end

    % --- 3. Add anchor points at the rounded corners (Curve) ---
    % Smoothens the U-shape at block intersections
    img_gt(row_bottom-2, col_left+2) = 0.6;
    img_gt(row_bottom-2, col_right-2) = 0.6;

    % =========================================================================
    % 3. INITIALIZE A SINGLE 16x16 PHI MATRIX
    % =========================================================================
    fprintf('Initializing common Phi Matrix 16x16 for 16 Tiles...\n');
    t_setup_start = tic;
    rng('shuffle');
    Phi_16 = randn(M_sub, N_sub^2);
    for j = 1:size(Phi_16, 2)
        Phi_16(:,j) = Phi_16(:,j) / norm(Phi_16(:,j));
    end
    t_setup_ms = toc(t_setup_start);

    % =========================================================================
    % 4. BLOCK DIVISION, LOG GENERATION AND DATA EXPORT PROCESS
    % =========================================================================
    img_recon_full = zeros(N_side, N_side);
    total_recon_time = t_setup_ms;
    Y_all_tiles = zeros(M_sub, 16); % Array to store all 16 vectors Y for C header export
    
    fprintf('\n--- PROCESSING 16 TILES AND EXPORTING INDIVIDUAL FILES ---\n');
    
    tile_cnt = 0;
    for r = 1:num_blocks_per_side
        for c = 1:num_blocks_per_side
            tile_cnt = tile_cnt + 1;
            
            % Extract local 16x16 image block
            row_range = (r-1)*N_sub + 1 : r*N_sub;
            col_range = (c-1)*N_sub + 1 : c*N_sub;
            sub_img = img_gt(row_range, col_range);
            
            % Compute measurement vector y for current tile
            t_start = tic;
            x_sub = sub_img(:);
            y_tile = Phi_16 * x_sub;
            Y_all_tiles(:, tile_cnt) = y_tile; % Store for C Header
            
            % --- 4.1 EXPORT DEBUG LOG (Used for cross-checking on Vivado) ---
            [x_hat_sub, ~, Debug] = OMP_Algorithm_Core(Phi_16, y_tile, K_sub);
            t_block = toc(t_start);
            total_recon_time = total_recon_time + t_block;
            img_recon_full(row_range, col_range) = reshape(x_hat_sub, [N_sub, N_sub]);
            save_debug_log(sprintf('omp_tile%d_debug.txt', tile_cnt), Debug, cfg.BW, cfg.FW);
            
            % --- 4.2 EXPORT INDIVIDUAL .COE FILE FOR EACH TILE ---
            y_txt_name = sprintf('y_tile%d.txt', tile_cnt);
            y_coe_name = sprintf('y_tile%d.coe', tile_cnt);
            export_to_hex_24bit(y_txt_name, y_tile, cfg.BW, cfg.FW);
            txt_to_coe_96bit(y_txt_name, y_coe_name);
            
            fprintf('Done Tile %2d: Created %s\n', tile_cnt, y_coe_name);
        end
    end

    % =========================================================================
    % 5. EXPORT C HEADER FILE (FOR XILINX SDK) - SPECIAL FEATURE
    % =========================================================================
    fprintf('\n[*] Creating C Header file "omp_bcs_data_64x64.h" for Xilinx SDK...\n');
    export_c_header('omp_bcs_data_64x64.h', Phi_16(:), Y_all_tiles, cfg.BW, cfg.FW);

    % =========================================================================
    % 6. PSNR CALCULATION AND DISPLAY
    % =========================================================================
    img_recon_full = max(0, img_recon_full);
    mse_val = mean((img_gt(:) - img_recon_full(:)).^2);
    psnr_val = 10 * log10(1.0^2 / (mse_val + eps));

    figure('Name', 'OMP Tiling 64x64 Reconstruction', 'Color', 'w', 'Position', [200, 200, 1000, 450]);

    % Subplot 1: Ground Truth
    subplot(1, 2, 1); 
    imagesc(img_gt); axis image; colormap gray; 
    title('Original Image (64x64)');
    xlabel('Ground Truth');

    % Subplot 2: Image Restoration
    subplot(1, 2, 2); 
    imagesc(img_recon_full); axis image; colormap gray; 
    title('Reconstructed Image from Software (Tiling-64x64-16 Tiles)');
    xlabel({sprintf('PSNR: %.2f dB', psnr_val); ...
            sprintf('Time: %.2f ms', total_recon_time * 1000)}, ...
            'FontSize', 11, 'FontWeight', 'normal');

    % Super title for the entire Figure window
    annotation('textbox', [0.35, 0.9, 0.3, 0.1], ...
        'String', '64x64 TILING RECONSTRUCTION', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');

    % =========================================================================
    % 7. EXPORT SHARED PHI MATRIX (FOR VIVADO)
    % =========================================================================
    export_to_hex_24bit('phi_16x16.txt', Phi_16(:), cfg.BW, cfg.FW);
    txt_to_coe_96bit('phi_16x16.txt', 'phi_16x16.coe');
    
    fprintf('\n>>> COMPLETE: 16 y_tile.coe files and 1 C Header file are ready.\n');
end

%% --- OMP CORE ALGORITHM ---
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

%% --- SAVE DEBUG LOG FUNCTION ---
function save_debug_log(filename, Debug, bw, fw)
    fid = fopen(filename, 'w');
    fprintf(fid, '--- OMP TILE DEBUG LOG (Q11.13) ---\n\n');
    for i = 1:length(Debug)
        fprintf(fid, 'ITERATION %d (Lambda: %d)\n', i-1, Debug(i).lambda);
        fprintf(fid, '  Energy u (Q26): %s\n', dec2hex_signed(Debug(i).u * 2^26, 64));
        fprintf(fid, '  Rii (ISR Q2.22): %s\n', dec2hex_signed(1/sqrt(Debug(i).u) * 2^22, 24));
        fprintf(fid, '  Alpha (Q11.13):  %s\n', dec2hex_signed(Debug(i).alpha * 2^fw, 24));
        fprintf(fid, '-----------------------------------\n');
    end
    fclose(fid);
end

%% --- EXPORT 96-BIT COE FUNCTION ---
function txt_to_coe_96bit(input_txt, output_coe)
    fid_in = fopen(input_txt, 'r');
    raw_data = textscan(fid_in, '%s');
    fclose(fid_in);
    raw_hex = raw_data{1};
    fid_out = fopen(output_coe, 'w');
    fprintf(fid_out, 'memory_initialization_radix=16;\nmemory_initialization_vector=\n');
    for i = 1:4:length(raw_hex)
        h1 = pad_hex(raw_hex{i}, 6);
        h2 = pad_hex(raw_hex{i+1}, 6);
        h3 = pad_hex(raw_hex{i+2}, 6);
        h4 = pad_hex(raw_hex{i+3}, 6);
        line_str = [h4, h3, h2, h1];
        if i + 4 > length(raw_hex), term = ';'; else, term = ','; end
        fprintf(fid_out, '%s%s\n', line_str, term);
    end
    fclose(fid_out);
end

%% --- GENERATE C HEADER FILE FOR SDK ---
function export_c_header(filename, Phi_data, Y_all, bw, fw)
    fid = fopen(filename, 'w');
    scale = 2^fw;
    
    fprintf(fid, '#ifndef OMP_BCS_DATA_64X64_H\n#define OMP_BCS_DATA_64X64_H\n\n');
    fprintf(fid, '#include "xil_types.h"\n\n');
    
    % Export Phi Matrix
    fprintf(fid, '// Phi matrix (16384 elements, Fixed-point Q11.13)\n');
    fprintf(fid, 'u32 phi_data[16384] = {\n');
    for i = 1:length(Phi_data)
        val = round(Phi_data(i) * scale);
        if val < 0, val = 2^bw + val; end
        if i == length(Phi_data), fprintf(fid, '0x%06X\n', val);
        else, fprintf(fid, '0x%06X, ', val); end
        if mod(i, 8) == 0, fprintf(fid, '\n'); end
    end
    fprintf(fid, '};\n\n');
    
    % Export 16 Y Arrays
    for t = 1:16
        fprintf(fid, '// Vector Y for block %d (64 elements)\n', t);
        fprintf(fid, 'u32 y_data_%d[64] = {\n', t);
        for i = 1:64
            val = round(Y_all(i, t) * scale);
            if val < 0, val = 2^bw + val; end
            if i == 64, fprintf(fid, '0x%06X\n', val);
            else, fprintf(fid, '0x%06X, ', val); end
            if mod(i, 8) == 0, fprintf(fid, '\n'); end
        end
        fprintf(fid, '};\n\n');
    end
    
    % Pointer array for convenience inside loops in C
    fprintf(fid, '// Pointer array to easily invoke loops\n');
    fprintf(fid, 'u32* y_blocks[16] = {');
    for t = 1:16
        if t == 16, fprintf(fid, 'y_data_%d};\n\n', t);
        else, fprintf(fid, 'y_data_%d, ', t); end
    end
    
    fprintf(fid, '#endif // OMP_BCS_DATA_64X64_H\n');
    fclose(fid);
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