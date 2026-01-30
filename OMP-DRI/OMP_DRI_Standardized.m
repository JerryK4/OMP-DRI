function OMP_DRI_Standardized
    clear; clc; close all;

    % 1. Thông s? mô ph?ng
    N1 = 16; M1 = 8;  K1 = 4;   % M?c 4x4 (16 pixels, 8 phép ?o)
    N2 = 64; M2 = 32; K2 = 16;  % M?c 8x8 (64 pixels, 32 phép ?o)

    %2. T?o ?nh g?c 8x8 th?c t?
    x_original = zeros(8, 8);
    x_original(2:3, 2:3) = 0.8; 
    x_original(6:7, 2:3) = 1.0; 
    x_original(4:5, 6:7) = 0.6; 
    x_true_8 = x_original(:);
%     %% ================= IMAGE (custom test pattern) =================
%         x_original = zeros(8,8);
% 
%         % ===== C?m 1 (Góc trên bên trái) =====
%         % Hàng 2: [Xám ??m, Tr?ng, Xám ??m]
%         x_original(2, 2:4) = [0.2, 1.0, 0.2]; 
%         % Hàng 3: [?en m?, Xám v?a, ?en m?]
%         x_original(3, 2:4) = [0.1, 0.5, 0.1];
% 
%         % ===== C?m 2 (Góc d??i bên trái) =====
%         % Hàng 6: [?en m?, Xám v?a, ?en m?]
%         x_original(6, 2:4) = [0.1, 0.5, 0.1];
%         % Hàng 7: [Xám ??m, Tr?ng, Xám ??m]
%         x_original(7, 2:4) = [0.2, 1.0, 0.2];
% 
%         % ===== C?m 3 (D?i d?c bên ph?i) =====
%         % Hàng 4: Xám ??m
%         x_original(4, 6:7) = 0.35; 
%         % Hàng 5: Xám sáng
%         x_original(5, 6:7) = 0.8;  
%         % Hàng 6: ?en m? (n?m ngang hàng v?i ph?n trên c?a c?m d??i bên trái)
%         x_original(6, 6:7) = 0.1;  
% 
%         % Vector hóa (?úng chu?n FPGA / OMP)
%         x_true_8 = x_original(:);



        


    

    % 3. THI?T K? MA TR?N PHI2 BAO HÀM PHI1 (Nguyên lý DRI)
    % T?o Phi1 ng?u nhiên cho m?c 4x4 (M1 x N1)
    Phi1 = randn(M1, N1);

    % T?o ph?n ??u c?a Phi2 b?ng cách upsampling Phi1
    % M?i pixel c?a mask 4x4 tr? thành kh?i 2x2 trong mask 8x8
    Phi2_top = zeros(M1, N2);
    for i = 1:M1
        mask4x4 = reshape(Phi1(i, :), 4, 4);
        mask8x8 = kron(mask4x4, ones(2, 2)); % Phóng ??i 2x2
        Phi2_top(i, :) = mask8x8(:)';
    end

    % T?o các phép ?o b? sung (ph?n d??i c?a Phi2) cho m?c 8x8
    Phi2_bottom = randn(M2 - M1, N2);

    % Ghép l?i thành Phi2 hoàn ch?nh (M2 x N2)
    Phi2 = [Phi2_top; Phi2_bottom];

    % 4. TH?C HI?N PHÉP ?O (SENSING)
    % Trong th?c t?, ta ch? ?o y2 ? ?? phân gi?i 8x8
    y2 = Phi2 * x_true_8;
    export_for_fpga(Phi2, y2);

    % DRI: y1 ???c l?y t? M1 ph?n t? ??u tiên c?a y2
    % (Vì Phi2_top là b?n upsample c?a Phi1, nên y1 này t??ng ???ng Phi1 * x_true_4)
    y1 = y2(1:M1);

    % 5. TÁI T?O (RECONSTRUCTION)
    % Tái t?o m?c 4x4
    [x_rec4_vec, ~] = OMP_DRI_Core(Phi1, y1, K1);
    
    % Tái t?o m?c 8x8 (S? d?ng toàn b? Phi2 và y2)
    [x_rec8_vec, ~] = OMP_DRI_Core(Phi2, y2, K2);

    % 6. Hi?n th? k?t qu?
    figure('Color', 'w', 'Name', 'OMP-DRI Standardized Results');
    
    subplot(1,3,1); imagesc(x_original, [0 1]); colormap gray; axis image;
    title('(a) 8x8 Original Image');
    
    subplot(1,3,2); imagesc(reshape(x_rec4_vec, 4, 4), [0 1]); colormap gray; axis image;
    title(sprintf('(b) 4x4 Recovery\n(Reuse y_2(1:8))'));

    subplot(1,3,3); imagesc(reshape(x_rec8_vec, 8, 8), [0 1]); colormap gray; axis image;
    title(sprintf('(c) 8x8 Recovery\n(Full 32 measurements)'));

    % Tính toán sai s? PSNR (Tham kh?o)
    psnr8 = 10 * log10(1 / (mean((x_true_8 - x_rec8_vec).^2)));
    fprintf('PSNR 8x8 Reconstruction: %.2f dB\n', psnr8);
end

function [x_hat, Lambda] = OMP_DRI_Core(Phi, y, K)
    [M, N] = size(Phi);
    Lambda = []; 
    Q = zeros(M, K); 
    U = zeros(K, K); 
    R = y; % Vector ph?n d? ban ??u
    
    for i = 1:K
        % B??C A: Tìm c?t t??ng quan nh?t (Block A trên FPGA)
        corr = abs(Phi' * R);
        if ~isempty(Lambda), corr(Lambda) = -1; end % Masking
        [~, lambda_i] = max(corr);
        
        % B??C B: Tr?c giao hóa (Block B - Modified Gram-Schmidt)
        Lambda = [Lambda, lambda_i];
        w = Phi(:, lambda_i);
        for j = 1:(i-1)
            U(j, i) = Q(:, j)' * w;
            w = w - U(j, i) * Q(:, j);
        end
        
        % Chu?n hóa và C?p nh?t Q
        U(i, i) = norm(w, 2); 
        if U(i, i) > 1e-12
            Q(:, i) = w / U(i, i);
        end
        
        % C?p nh?t Residual R
        % R = R - (Q_i * Q_i' * R)
        alpha = Q(:, i)' * R;
        R = R - alpha * Q(:, i);
    end
    
    % B??C C: ??c l??ng tín hi?u (Block C trên FPGA)
    % Gi?i h? ph??ng trình x_sparse = U \ (Q' * y)
    x_sparse = U \ (Q' * y);
    x_hat = zeros(N, 1);
    x_hat(Lambda) = x_sparse;
end

function export_for_fpga(Phi, y)
    BW = 24; % T?ng s? bit
    FW = 13; % S? bit sau d?u ph?y
    scale = 2^FW;
    [M, N] = size(Phi);

    % --- 1. Xu?t file COE cho Ma tr?n Phi (?óng gói 4 ph?n t? = 96 bit) ---
    fid = fopen('phi_matrix.coe', 'w');
    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');
    
    for col = 1:N
        % Vì NUM_P = 4, ta g?p 4 hàng thành 1 dòng 96-bit
        for row_grp = 1:4:M
            % L?y 4 ph?n t? (??m b?o không v??t quá M)
            idx = row_grp : min(row_grp+3, M);
            vals = Phi(idx, col);
            
            % Chuy?n sang Hex 24-bit và ghép l?i thành chu?i 96-bit {P3, P2, P1, P0}
            hex_str = '';
            for k = length(idx):-1:1
                hex_str = [hex_str, dec2hex_signed(vals(k) * scale, BW)];
            end
            % N?u thi?u ph?n t? (trong tr??ng h?p M không chia h?t cho 4), bù 0
            if length(idx) < 4
                for k = 1:(4-length(idx))
                    hex_str = ['000000', hex_str];
                end
            end
            
            % Ghi vào file
            if (col == N && row_grp >= M-3)
                fprintf(fid, '%s;\n', hex_str);
            else
                fprintf(fid, '%s,\n', hex_str);
            end
        end
    end
    fclose(fid);

    % --- 2. Xu?t file COE cho Vector y (?óng gói 96 bit) ---
    fid = fopen('y_vector.coe', 'w');
    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');
    
    for row_grp = 1:4:M
        idx = row_grp : min(row_grp+3, M);
        vals = y(idx);
        hex_str = '';
        for k = length(idx):-1:1
            hex_str = [hex_str, dec2hex_signed(vals(k) * scale, BW)];
        end
        if length(idx) < 4
            for k = 1:(4-length(idx))
                hex_str = ['000000', hex_str];
            end
        end
        
        if (row_grp >= M-3)
            fprintf(fid, '%s;\n', hex_str);
        else
            fprintf(fid, '%s,\n', hex_str);
        end
    end
    fclose(fid);
    
    fprintf('>>> ?ã t?o xong phi_matrix.coe và y_vector.coe!\n');
end

function hex_str = dec2hex_signed(val, bw)
    % Chuy?n s? th?c sang s? nguyên fixed-point
    v = round(val);
    % X? lý s? âm (Bù 2)
    if v < 0
        v = 2^bw + v;
    end
    hex_str = dec2hex(v, bw/4);
end