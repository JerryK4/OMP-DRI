%% ========================================================================
%  H? TH?NG GIÁM SÁT TERMINAL VÀ SO SÁNH KHÔI PH?C ?NH DRI TH?I GIAN TH?C
%  Phiên b?n: So sánh Ground Truth - T??ng thích MATLAB R2016a/b
%  ========================================================================

clc; clear; close all;

% --- 1. C?U HÌNH C?NG COM C? ??NH ---
portName = 'COM4';  
baudRate = 115200;

% --- 2. T?O ?NH G?C (GROUND TRUTH) 16x16 ---
img_gt = zeros(16, 16);
img_gt(4, 4) = 1.0;         
img_gt(4, 5) = 0.6; img_gt(5, 4) = 0.6; 
img_gt(12:13, 12:13) = 0.8; 
img_gt(8, 8) = 0.9;         
img_gt(7, 8) = 0.5; img_gt(9, 8) = 0.5;
img_gt(8, 7) = 0.5; img_gt(8, 9) = 0.5;

% --- 3. D?N D?P C?NG COM TR??C KHI CH?Y ---
objs = instrfind('Port', portName);
if ~isempty(objs)
    fclose(objs);
    delete(objs);
end

% --- 4. KH?I T?O K?T N?I UART ---
s = serial(portName, 'BaudRate', baudRate, 'Terminator', 'CR/LF');

try
    fopen(s);
    flushinput(s);
    fprintf('>>> DA KET NOI VOI %s. HAY NHAN "RUN" TREN SDK.\n', portName);
catch
    error('LOI: KHONG THE MO %s. HAY CHAC CHAN BAN DA DONG SDK Terminal!', portName);
end

% --- 5. KH?I T?O MA TR?N ?NH VÀ GIAO DI?N ---
img4  = zeros(4, 4);
img8  = zeros(8, 8);
img16 = zeros(16, 16);

hFig = figure('Name', 'DRI Real-time Comparison: Ground Truth vs HW Recovery', ...
              'Color', 'w', 'Position', [50, 150, 1400, 400]);

% T?o giao di?n 4 ô ?nh (1x4)
% Ô 1: ?nh g?c
subplot(1,4,1); imagesc(img_gt); axis image; colormap gray; 
title('Ground Truth (16x16)'); ylabel('Original');

% Ô 2: Stage 4x4 (???c phóng lên 16x16)
subplot(1,4,2); h4_plot = imagesc(zeros(16,16)); axis image; 
title('Stage 1: 4x4'); xlabel('Upsampled');

% Ô 3: Stage 8x8 (???c phóng lên 16x16)
subplot(1,4,3); h8_plot = imagesc(zeros(16,16)); axis image; 
title('Stage 2: 8x8'); xlabel('Upsampled');

% Ô 4: Stage 16x16
subplot(1,4,4); h16_plot = imagesc(img16); axis image; 
hTitle16 = title('Stage 3: 16x16'); ylabel('Final Recovery');

current_stage = 0;

% --- 6. VÒNG L?P CHÍNH (Terminal + Processing) ---
while ishandle(hFig)
    if s.BytesAvailable > 0
        line = fgetl(s); 
        fprintf('%s\n', line); % In ra Command Window gi?ng Terminal
        
        % Nh?n di?n Giai ?o?n (S? d?ng strfind cho b?n c?)
        if ~isempty(strfind(line, 'STAGE 1'))
            current_stage = 1; img4 = zeros(4,4);
        elseif ~isempty(strfind(line, 'STAGE 2'))
            current_stage = 2; img8 = zeros(8,8);
        elseif ~isempty(strfind(line, 'STAGE 3'))
            current_stage = 3; img16 = zeros(16,16);
        end
        
        % Bóc tách d? li?u: | Lambda | Val
        tokens = regexp(line, '\|\s*(\d+)\s*\|\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        
        if ~isempty(tokens)
            lambda = str2double(tokens{1}{1});
            val    = str2double(tokens{1}{2});
            
            % ?i?n pixel vào ma tr?n t??ng ?ng
            if current_stage == 1 && lambda < 16
                img4(lambda + 1) = val;
                % Phóng to lên 16x16 ?? so sánh
                set(h4_plot, 'CData', imresize(img4, [16 16], 'nearest'));
            elseif current_stage == 2 && lambda < 64
                img8(lambda + 1) = val;
                % Phóng to lên 16x16 ?? so sánh
                set(h8_plot, 'CData', imresize(img8, [16 16], 'nearest'));
            elseif current_stage == 3 && lambda < 256
                img16(lambda + 1) = val;
                set(h16_plot, 'CData', img16);
                
                % TÍNH TOÁN PSNR CHO STAGE CU?I
                mse = mean((img_gt(:) - img16(:)).^2);
                if mse > 0
                    psnr_val = 10 * log10(1 / mse);
                    set(hTitle16, 'String', sprintf('Stage 3: 16x16 (PSNR: %.2f dB)', psnr_val));
                end
            end
            
            drawnow limitrate;
        end
    end
    pause(0.001); 
end

% --- 7. K?T THÚC ---
if exist('s', 'var')
    fclose(s);
    delete(s);
end
fprintf('\n>>> DA DONG KET NOI UART.\n');