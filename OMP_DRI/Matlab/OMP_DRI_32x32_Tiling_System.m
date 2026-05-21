function OMP_DRI_32x32_Tiling_Individual_Export
    clear; clc; close all;

    % =========================================================================
    % 1. TILING SYSTEM CONFIGURATION (4 blocks of 16x16)
    % =========================================================================
    cfg.BW = 24;               
    cfg.FW = 13;               
    
    N_sub  = 16;               
    M_sub  = 64;               
    K_sub  = 16;               
    N_side = 32;               
    num_blocks_per_side = N_side / N_sub; 

    % =========================================================================
    % 2. GENERATE ORIGINAL IMAGE (GROUND TRUTH) 32x32 - SYMMETRIC GEOMETRIC PATTERN
    % Each 16x16 block has its own motif to verify Tiling accuracy
    % =========================================================================
    N_side = 32;
    img_gt = zeros(N_side, N_side);

    % --- COMPONENT 1: 2x2 solid core at the center (intersection of 4 blocks) ---
    % Each block will receive exactly 1 pixel from the center of the large image
    img_gt(16:17, 16:17) = 1.0; 

    % --- COMPONENT 2: Hollow octagonal frame (Cross-border connectivity) ---
    % Top horizontal edge (crosses column boundary 16-17)
    img_gt(10, 14:19) = 0.8; % 3 pixels in block 1, 3 pixels in block 2
    % Bottom horizontal edge (crosses column boundary 16-17)
    img_gt(23, 14:19) = 0.8; % 3 pixels in block 3, 3 pixels in block 4
    % Left vertical edge (crosses row boundary 16-17)
    img_gt(14:19, 10) = 0.8; % 3 pixels in block 1, 3 pixels in block 3
    % Right vertical edge (crosses row boundary 16-17)
    img_gt(14:19, 23) = 0.8; % 3 pixels in block 2, 3 pixels in block 4

    % --- COMPONENT 3: Symmetrical anchor points at 4 corners ---
    img_gt(5, 5)   = 0.6;  % Corner of block 1
    img_gt(5, 28)  = 0.6;  % Corner of block 2
    img_gt(28, 5)  = 0.6;  % Corner of block 3
    img_gt(28, 28) = 0.6;  % Corner of block 4

    % =========================================================================
    % 3. BLOCK STITCHING MAP CONFIGURATION (TILING MAP)
    % =========================================================================
    tile_offsets = [
         1,  1;   % Tile 1: Top-Left
         1, 17;   % Tile 2: Top-Right
        17,  1;   % Tile 3: Bottom-Left
        17, 17    % Tile 4: Bottom-Right
    ];

    img_recon = zeros(N_side, N_side);
    % Large array variable to temporarily store 4 vectors Y (4 columns, 64 elements each)
    Y_all_tiles = zeros(M_sub, 4); 

    % =========================================================================
    % 4. INITIALIZE A SINGLE 16x16 PHI MATRIX
    % =========================================================================
    fprintf('Initializing common Phi Matrix 16x16 for 4 Tiles...\n');
    t_setup_start = tic;
    rng('shuffle');
    Phi_16 = randn(M_sub, N_sub^2);
    for j = 1:size(Phi_16, 2)
        Phi_16(:,j) = Phi_16(:,j) / norm(Phi_16(:,j));
    end
    t_setup_ms = toc(t_setup_start);

    % =========================================================================
    % 5. BLOCK DIVISION PROCESS AND TIMING MEASUREMENT
    % =========================================================================
    img_recon_full = zeros(N_side, N_side);
    total_recon_time = t_setup_ms;
    
    tile_cnt = 0;
    for r = 1:num_blocks_per_side
        for c = 1:num_blocks_per_side
            tile_cnt = tile_cnt + 1;
            row_range = (r-1)*N_sub + 1 : r*N_sub;
            col_range = (c-1)*N_sub + 1 : c*N_sub;
            
            t_start = tic;
            sub_img = img_gt(row_range, col_range);
            y_tile = Phi_16 * sub_img(:);
            
            Y_all_tiles(:, tile_cnt) = y_tile; 
            
            % --- ALGORITHM TIMING MEASUREMENT ---
            [x_hat_sub, ~, Debug] = OMP_Algorithm_Core(Phi_16, y_tile, K_sub);
            t_block = toc(t_start);
            
            total_recon_time = total_recon_time + t_block;
            img_recon_full(row_range, col_range) = reshape(x_hat_sub, [N_sub, N_sub]);
            
            % Export COE and Log files (for Vivado Simulation)
            y_txt_name = sprintf('y_tile%d.txt', tile_cnt);
            y_coe_name = sprintf('y_tile%d.coe', tile_cnt);
            export_to_hex_24bit(y_txt_name, y_tile, cfg.BW, cfg.FW);
            txt_to_coe_96bit(y_txt_name, y_coe_name);
            save_debug_log(sprintf('omp_tile%d_debug.txt', tile_cnt), Debug, cfg.BW, cfg.FW);
        end
    end

    % =========================================================================
    % 6. ERROR CALCULATION AND DISPLAY
    % =========================================================================
    img_recon_full(img_recon_full < 0) = 0; % Filter out negative noise
    mse_val = mean((img_gt(:) - img_recon_full(:)).^2);
    psnr_val = 10 * log10(1.0 / (mse_val + eps));

    figure('Color', 'w', 'Name', 'BCS Tiling Analysis', 'Position', [100, 200, 1100, 500]);

    % Subplot 1: Original Image
    subplot(1,2,1);
    imagesc(img_gt); colormap gray; axis image;
    title('Original Image (Ground Truth)', 'FontSize', 12);
    xlabel('32x32 Pixels');

    % Subplot 2: Reconstructed Image
    subplot(1,2,2);
    imagesc(img_recon_full); colormap gray; axis image;
    title('Reconstructed Image from Software (Tiling-32x32-4 Tiles)', 'FontSize', 12);
    
    % DISPLAY PARAMETERS BELOW THE IMAGE
    % Use {} brackets for line breaks inside xlabel
    xlabel({sprintf('PSNR: %.2f dB', psnr_val); ...
            sprintf('Time: %.2f ms', total_recon_time * 1000)}, ...
            'FontSize', 11, 'FontWeight', 'normal');

    % =========================================================================
    % 7. EXPORT SHARED PHI MATRIX
    % =========================================================================
    export_to_hex_24bit('phi_16x16.txt', Phi_16(:), cfg.BW, cfg.FW);
    txt_to_coe_96bit('phi_16x16.txt', 'phi_16x16.coe');
    
    export_c_header('omp_bcs_data.h', Phi_16(:), Y_all_tiles, cfg.BW, cfg.FW);
    
    fprintf('\n>>> COMPLETE: All 4 y_tileX.coe files are ready.\n');
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

%% --- EXPORT 96-BIT COE FUNCTION (Packs 4 elements of 24-bit) ---
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
        % Concatenate backwards for correct order {p3, p2, p1, p0}
        line_str = [h4, h3, h2, h1];
        if i + 4 > length(raw_hex), term = ';'; else, term = ','; end
        fprintf(fid_out, '%s%s\n', line_str, term);
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

%% --- GENERATE C HEADER FILE DIRECTLY FROM MATLAB VARIABLES ---
function export_c_header(filename, Phi_data, Y_all, bw, fw)
    fid = fopen(filename, 'w');
    scale = 2^fw;
    
    fprintf(fid, '/* ==========================================================\n');
    fprintf(fid, ' * DATA FILE AUTOMATICALLY GENERATED FROM MATLAB (32x32 TILING)\n');
    fprintf(fid, ' * Used for Xilinx SDK / Vitis (AXI DMA)\n');
    fprintf(fid, ' * ========================================================== */\n\n');
    
    fprintf(fid, '#ifndef OMP_BCS_DATA_32X32_H\n#define OMP_BCS_DATA_32X32_H\n\n');
    fprintf(fid, '#include "xil_types.h"\n\n');
    
    % Export Phi Matrix
    fprintf(fid, '// Phi matrix (16384 elements, Fixed-point Q11.13)\n');
    fprintf(fid, 'u32 phi_data[16384] __attribute__((aligned(32))) = {\n');
    for i = 1:length(Phi_data)
        val = round(Phi_data(i) * scale);
        if val < 0, val = 2^bw + val; end
        if i == length(Phi_data), fprintf(fid, '    0x%06X\n', val);
        else, fprintf(fid, '    0x%06X, ', val); end
        if mod(i, 8) == 0, fprintf(fid, '\n'); end
    end
    fprintf(fid, '};\n\n');
    
    % Export 4 Y Arrays
    for t = 1:4
        fprintf(fid, '// Vector Y for block %d (64 elements)\n', t);
        fprintf(fid, 'u32 y_data_%d[64] __attribute__((aligned(32))) = {\n', t);
        for i = 1:64
            val = round(Y_all(i, t) * scale);
            if val < 0, val = 2^bw + val; end
            if i == 64, fprintf(fid, '    0x%06X\n', val);
            else, fprintf(fid, '    0x%06X, ', val); end
            if mod(i, 8) == 0, fprintf(fid, '\n'); end
        end
        fprintf(fid, '};\n\n');
    end
    
    fprintf(fid, '#endif // OMP_BCS_DATA_32X32_H\n');
    fclose(fid);
end