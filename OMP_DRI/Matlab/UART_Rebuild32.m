%% ========================================================================
%  H? TH?NG GIÁM SÁT VÀ SO SÁNH KHÔI PH?C ?NH TILING 32x32 (BCS OMP)
%  Phiên b?n: Hoàn ch?nh - T??ng thích MATLAB R2016a/b
%  Ch?c n?ng: Nh?n 4 kh?i 16x16, so sánh Ground Truth, tính PSNR th?c t?
%  ========================================================================

clc; clear; close all;

% --- 1. C?U HÌNH C?NG COM ---
portName = 'COM4';  % <--- THAY ??I C?NG COM C?A B?N T?I ?ÂY
baudRate = 115200;

% --- 2. T?O ?NH G?C (GROUND TRUTH) 32x32 ---
N_side = 32;
img_gt = zeros(N_side, N_side);

% TILE 1 (Trên - Trái)
img_gt(14:16, 14) = 0.8; 
img_gt(16, 15:16) = 0.8; 
img_gt(15, 15)    = 1.0; 

% TILE 2 (Trên - Ph?i)
img_gt(14:16, 19) = 0.8; 
img_gt(16, 17:18) = 0.8;
img_gt(15, 18)    = 1.0;

% TILE 3 (D??i - Trái)
img_gt(17:19, 14) = 0.8;
img_gt(17, 15:16) = 0.8;
img_gt(18, 15)    = 1.0;

% TILE 4 (D??i - Ph?i)
img_gt(17:19, 19) = 0.8;
img_gt(17, 17:18) = 0.8;
img_gt(18, 18)    = 1.0;

% --- 3. D?N D?P VÀ KH?I T?O UART ---
objs = instrfind('Port', portName);
if ~isempty(objs), fclose(objs); delete(objs); end

s = serial(portName, 'BaudRate', baudRate, 'Terminator', 'CR/LF');
try
    fopen(s);
    flushinput(s);
    fprintf('>>> DA KET NOI %s. DANG DOI DU LIEU TILING...\n', portName);
catch
    error('LOI: Khong the mo cong %s. Hay dong SDK Terminal!', portName);
end

% --- 4. KHOI TAO GIAO DIEN HIEN THI ---
full_img_recon = zeros(32, 32);
hFig = figure('Name', 'BCS 32x32: Ground Truth vs FPGA Recovery', 'Color', 'w', ...
              'Position', [50, 100, 1100, 500]);

% Subplot 1: ?nh g?c
subplot(1,2,1); imagesc(img_gt); colormap gray; axis image;
title('Anh Goc (Ground Truth)'); xlabel('32x32 Pixel');
colorbar;

% Subplot 2: ?nh khôi ph?c t? FPGA
subplot(1,2,2); hImg = imagesc(full_img_recon); colormap gray; axis image;
hTitle = title('Anh FPGA: Dang doi du lieu...'); 
xlabel('Ghep tu 4 khoi 16x16');
colorbar;

% ??nh ngh?a Offset cho 4 kh?i
offsets = [ 0, 0; 0, 16; 16, 0; 16, 16]; 
current_tile = 0;

% --- 5. VONG LAP NHAN DU LIEU VA TINH PSNR ---
while ishandle(hFig)
    if s.BytesAvailable > 0
        line = fgetl(s);
        fprintf('%s\n', line); % In log Terminal
        
        % A. Nh?n di?n Tile
        if ~isempty(strfind(line, 'CHAY KHOI'))
            tokens_tile = regexp(line, 'CHAY KHOI (\d+)', 'tokens');
            if ~isempty(tokens_tile)
                current_tile = str2double(tokens_tile{1}{1});
            end
        end
        
        % B. Bóc tách d? li?u Pixel: | Lambda | Cuong do
        tokens_px = regexp(line, '\|\s*(\d+)\s*\|\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        
        if ~isempty(tokens_px) && current_tile > 0
            lambda = str2double(tokens_px{1}{1});
            val    = str2double(tokens_px{1}{2});
            
            % Mapping Lambda 16x16 -> To? ?? 32x32
            col_local = floor(lambda / 16);
            row_local = mod(lambda, 16);
            row_global = row_local + offsets(current_tile, 1) + 1;
            col_global = col_local + offsets(current_tile, 2) + 1;
            
            % C?p nh?t pixel (L?c nhi?u âm)
            full_img_recon(row_global, col_global) = max(0, val);
            set(hImg, 'CData', full_img_recon);
            
            % --- C. TINH TOAN PSNR THOI GIAN THUC ---
            mse = mean((img_gt(:) - full_img_recon(:)).^2);
            if mse > 0
                psnr_val = 10 * log10(1.0 / mse);
                set(hTitle, 'String', sprintf('Anh Phuc Hoi FPGA (PSNR: %.2f dB)', psnr_val));
            else
                set(hTitle, 'String', 'Anh Phuc Hoi FPGA (PSNR: Inf)');
            end
            
            drawnow limitrate;
        end
    end
    pause(0.001);
end

% --- 6. K?T THÚC ---
fclose(s); delete(s);
fprintf('\n>>> Da dong ket noi UART.\n');