function OMP_DRI_Full_System_With_PSNR
    clear; clc; close all;

    % 1. C?U HÌNH H? TH?NG (Fixed-point 24-bit: Q11.13)
    cfg.BW = 24;               
    cfg.FW = 13;               
    cfg.Levels = [4, 8, 16];    
    cfg.M_list = [8, 16, 64];   
    cfg.K_list = [4, 6, 16];    

%     % 2. T?O ?NH G?C 16x16 (Pattern ch? th?p theo yêu c?u)
%     img_gt = zeros(16, 16);
%     img_gt(4,4) = 1.0; 
%     img_gt(3,4) = 0.6; img_gt(5,4) = 0.6; img_gt(4,3) = 0.6; img_gt(4,5) = 0.6;
%     img_gt(12,4) = 1.0; 
%     img_gt(11,4) = 0.6; img_gt(13,4) = 0.6; img_gt(12,3) = 0.6; img_gt(12,5) = 0.6;
%     img_gt(8:9, 11:13) = 0.8;
%     x_gt_full = img_gt(:);
    % 2. T?O ?NH G?C XÁM TH?A 16x16 (Symmetry Sparse Pattern)
    img_gt = zeros(16, 16);
    
%     T?o các c?m ?i?m th?a th?t (Sparse Clusters)
    img_gt(4, 4) = 1.0;         % ?i?m ??n r?c r?
    img_gt(4, 5) = 0.6; img_gt(5, 4) = 0.6; % Vùng chuy?n m?
    
    img_gt(12:13, 12:13) = 0.8; % Kh?i 2x2 ? góc ??i di?n
    
    img_gt(8, 8) = 0.9;         % ?i?m trung tâm
    img_gt(7, 8) = 0.5; img_gt(9, 8) = 0.5;
    img_gt(8, 7) = 0.5; img_gt(8, 9) = 0.5;

%     img_gt = zeros(16, 16);
%     img_gt(6, 7) = 0.6;          % ??nh h?i m?
%     img_gt(7:10, 7) = 1.0;       % Thân tr?ng sáng
%     img_gt(11, 7) = 0.4;         % Chân góc m? h?n
% 
%     % C?t ph?i c?a ch? U (C?t 10)
%     img_gt(6, 10) = 0.6;         % ??nh h?i m?
%     img_gt(7:10, 10) = 1.0;      % Thân tr?ng sáng
%     img_gt(11, 10) = 0.4;        % Chân góc m? h?n
% 
%     % ?áy c?a ch? U (Hàng 11, n?i gi?a c?t 7 và 10)
%     img_gt(11, 8:9) = 0.8;       % ?áy tr?ng v?a
%     
%     % Ph?n ?? bóng nh? bên trong ?áy (Hàng 10)
%     img_gt(10, 8:9) = 0.2;       % Vùng t?i nh? bên trong
    
    % T?ng s? pixel khác 0 (K_actual) kho?ng 12-14 -> R?t th?a
    x_gt_full = img_gt(:);

    % 3. T?O D? LI?U ?O (DRI Measurement Reuse)
    rng('shuffle'); 
    Phi_max = randn(max(cfg.M_list), 16*16);
    for j = 1:size(Phi_max, 2)
        Phi_max(:,j) = Phi_max(:,j) / norm(Phi_max(:,j));
    end
    y_full = Phi_max * x_gt_full; 

    % 4. HI?N TH? VÀ CH?Y DRI
    fprintf('--- B?T ??U QUY TRÌNH OMP-DRI & SO SÁNH PSNR ---\n');
    fprintf('%-10s | %-10s | %-10s | %-10s\n', 'Level', 'Resolution', 'M (Phép ?o)', 'PSNR (dB)');
    fprintf('------------------------------------------------------------\n');
    
    figure('Color', 'w', 'Name', 'OMP-DRI Analysis: PSNR Comparison', 'Position', [100, 300, 1400, 350]);
    
    % Subplot 1: ?nh G?c
    subplot(1, 4, 1);
    imagesc(img_gt); colormap gray; axis image;
    title('Original Image (16x16)');
    xlabel('Ground Truth');

    for lv = 1:length(cfg.Levels)
        n = cfg.Levels(lv);
        M = cfg.M_list(lv);
        K = cfg.K_list(lv);
        N = n^2;

        % C?t ma tr?n và vector ?o (DRI Reuse)
        Phi_lv = Phi_max(1:M, 1:N);
        y_lv = y_full(1:M);

        % Thu?t toán OMP Core
        [x_hat, Lambda, Debug] = OMP_Algorithm_Core(Phi_lv, y_lv, K, cfg);
        img_rec = reshape(x_hat, [n, n]);

        % --- TÍNH TOÁN PSNR ---
        % ??a ?nh tái t?o v? 16x16 ?? so sánh bit-to-bit
        img_resized = imresize(img_rec, [16 16], 'nearest');
        mse_val = mean((img_gt(:) - img_resized(:)).^2);
        if mse_val > 0
            psnr_val = 10 * log10(1 / mse_val);
        else
            psnr_val = Inf;
        end

        % In k?t qu? ra Command Window
        fprintf('Level %-5d | %-2dx%-7d | %-10d | %-10.2f\n', lv, n, n, M, psnr_val);

        % Hi?n th? ?nh
        subplot(1, 4, lv + 1);
        imagesc(img_rec); colormap gray; axis image;
        title(sprintf('Level %d (%dx%d)', lv, n, n));
        xlabel(sprintf('M=%d, PSNR=%.2f dB', M, psnr_val));

        % --- XU?T FILE (COE & LOG) ---
        prefix = sprintf('lv%d_%dx%d_', lv, n, n);
        export_to_hex_24bit([prefix, 'phi.txt'], Phi_lv(:), cfg.BW, cfg.FW);
        export_to_hex_24bit([prefix, 'y.txt'], y_lv, cfg.BW, cfg.FW);
        txt_to_coe_96bit([prefix, 'phi.txt'], [prefix, 'phi.coe']);
        txt_to_coe_96bit([prefix, 'y.txt'],   [prefix, 'y.coe']);
        save_debug_log([prefix, 'omp_golden_debug.txt'], Debug, cfg.BW, cfg.FW);
    end
    fprintf('------------------------------------------------------------\n');
end

%% --- THU?T TOÁN OMP CORE (QR/MGS) ---
function [x_hat, Lambda, Debug] = OMP_Algorithm_Core(Phi, y, K, cfg)
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
        u = sum(w.^2);
        R(i, i) = sqrt(u);
        Q(:, i) = w / R(i, i);

        alpha = Q(:, i)' * y;
        res = res - alpha * Q(:, i);

        Debug(i).lambda = pos - 1;
        Debug(i).u = u;
        Debug(i).alpha = alpha;
        Debug(i).R_col = R(1:i, i);
    end
    alphas = [Debug.alpha]';
    R_final = R(1:length(Lambda), 1:length(Lambda));
    coeffs = R_final \ alphas;
    x_hat = zeros(N, 1);
    x_hat(Lambda) = coeffs;
end

%% --- HÀM L?U LOG GOLDEN DEBUG ---
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

%% --- HÀM XU?T COE 96-BIT ---
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

%% --- HÀM PH? TR? ---
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