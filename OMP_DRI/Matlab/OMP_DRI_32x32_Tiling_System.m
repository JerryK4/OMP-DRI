function OMP_DRI_32x32_Tiling_Individual_Export
    clear; clc; close all;

    % =========================================================================
    % 1. C?U HÌNH H? TH?NG TILING (4 kh?i 16x16)
    % =========================================================================
    cfg.BW = 24;               
    cfg.FW = 13;               
    
    N_sub  = 16;               
    M_sub  = 64;               
    K_sub  = 16;               
    N_side = 32;               
    num_blocks_per_side = N_side / N_sub; 

    % =========================================================================
    % 2. T?O ?NH G?C 32x32 (M?u Nested Squares)
    % =========================================================================
%     img_gt = zeros(N_side, N_side);
%     img_gt(11, 11:21) = 0.6; img_gt(21, 11:21) = 0.6;
%     img_gt(11:21, 11) = 0.6; img_gt(11:21, 21) = 0.6;
%     img_gt(11, 16) = 0.9; img_gt(21, 16) = 0.9;
%     img_gt(16, 11) = 0.9; img_gt(16, 21) = 0.9;
%     img_gt(15:16, 15:16) = 1.0; 
    
    img_gt = zeros(N_side, N_side);
    
    % --- TILE 1 (Trên - Trái): 6 pixel ---
    img_gt(14:16, 14) = 0.8; % Thanh ??ng
    img_gt(16, 15:16) = 0.8; % Thanh ngang
    img_gt(15, 15)    = 1.0; % ?i?m nh?n tâm kh?i

    % --- TILE 2 (Trên - Ph?i): 6 pixel ---
    img_gt(14:16, 19) = 0.8; 
    img_gt(16, 17:18) = 0.8;
    img_gt(15, 18)    = 1.0;

    % --- TILE 3 (D??i - Trái): 6 pixel ---
    img_gt(17:19, 14) = 0.8;
    img_gt(17, 15:16) = 0.8;
    img_gt(18, 15)    = 1.0;

    % --- TILE 4 (D??i - Ph?i): 6 pixel ---
    img_gt(17:19, 19) = 0.8;
    img_gt(17, 17:18) = 0.8;
    img_gt(18, 18)    = 1.0;

    % =========================================================================
    % 3. KH?I T?O MA TR?N PHI 16x16 DUY NH?T
    % =========================================================================
    fprintf('Kh?i t?o Ma tr?n Phi 16x16 chung cho 4 Tile...\n');
    rng('shuffle');
    Phi_16 = randn(M_sub, N_sub^2);
    for j = 1:size(Phi_16, 2)
        Phi_16(:,j) = Phi_16(:,j) / norm(Phi_16(:,j));
    end

    % =========================================================================
    % 4. QUY TRÌNH CHIA KH?I, XU?T LOG VÀ XU?T FILE .COE RIÊNG BI?T
    % =========================================================================
    img_recon_full = zeros(N_side, N_side);
    
    fprintf('\n--- ?ANG X? LÝ 4 TILE VÀ XU?T FILE RIÊNG BI?T ---\n');
    
    tile_cnt = 0;
    for r = 1:num_blocks_per_side
        for c = 1:num_blocks_per_side
            tile_cnt = tile_cnt + 1;
            
            % Trích xu?t vùng ?nh con
            row_range = (r-1)*N_sub + 1 : r*N_sub;
            col_range = (c-1)*N_sub + 1 : c*N_sub;
            sub_img = img_gt(row_range, col_range);
            
            % Tính toán vector y cho tile hi?n t?i
            x_sub = sub_img(:);
            y_tile = Phi_16 * x_sub;
            
            % --- 4.1 XU?T LOG DEBUG (Dùng ?? ??i chi?u t?ng b??c) ---
            [x_hat_sub, ~, Debug] = OMP_Algorithm_Core(Phi_16, y_tile, K_sub);
            img_recon_full(row_range, col_range) = reshape(x_hat_sub, [N_sub, N_sub]);
            save_debug_log(sprintf('omp_tile%d_debug.txt', tile_cnt), Debug, cfg.BW, cfg.FW);
            
            % --- 4.2 XU?T FILE .COE RIÊNG CHO T?NG Y ---
            y_txt_name = sprintf('y_tile%d.txt', tile_cnt);
            y_coe_name = sprintf('y_tile%d.coe', tile_cnt);
            export_to_hex_24bit(y_txt_name, y_tile, cfg.BW, cfg.FW);
            txt_to_coe_96bit(y_txt_name, y_coe_name);
            
            fprintf('Xong Tile %d: ?ã t?o %s và Log.\n', tile_cnt, y_coe_name);
        end
    end

    % =========================================================================
    % 5. TÍNH PSNR VÀ HI?N TH?
    % =========================================================================
    img_recon_full = max(0, img_recon_full);
    mse_val = mean((img_gt(:) - img_recon_full(:)).^2);
    psnr_val = 10 * log10(1.0^2 / (mse_val + eps));

    figure('Color', 'w', 'Name', 'OMP Tiling 32x32');
    subplot(1,2,1); imagesc(img_gt); colormap gray; axis image; title('Origial Image 32x32');
    subplot(1,2,2); imagesc(img_recon_full); colormap gray; axis image; 
    title(['Image restoration', char(10), 'PSNR = ', num2str(psnr_val), ' dB']);

    % =========================================================================
    % 6. XU?T MA TR?N PHI CHUNG
    % =========================================================================
    export_to_hex_24bit('phi_16x16.txt', Phi_16(:), cfg.BW, cfg.FW);
    txt_to_coe_96bit('phi_16x16.txt', 'phi_16x16.coe');
    
    fprintf('\n>>> HOÀN T?T: Toàn b? 4 file y_tileX.coe ?ã s?n sàng.\n');
end

%% --- THU?T TOÁN OMP CORE ---
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

%% --- HÀM L?U LOG DEBUG ---
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

%% --- HÀM XU?T COE 96-BIT (?óng gói 4 ph?n t? 24-bit) ---
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
        % Ghép ng??c ?? ?úng th? t? {p3, p2, p1, p0}
        line_str = [h4, h3, h2, h1];
        if i + 4 > length(raw_hex), term = ';'; else, term = ','; end
        fprintf(fid_out, '%s%s\n', line_str, term);
    end
    fclose(fid_out);
end

%% --- CÁC HÀM PH? TR? ---
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