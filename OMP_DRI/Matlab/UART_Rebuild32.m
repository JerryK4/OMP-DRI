%% ========================================================================
%  MONITORING AND COMPARISON SYSTEM FOR TILING 32x32 IMAGE RECONSTRUCTION (BCS OMP)
%  Version: Displays Execution Time (us) - R2016a/b Compatible
%  =======================================================================

clc; clear; close all;

% --- 1. COM PORT CONFIGURATION ---
portName = 'COM4';  % <--- CHANGE YOUR COM PORT HERE
baudRate = 115200;

% --- 2. GENERATE ORIGINAL IMAGE (GROUND TRUTH) 32x32 ---
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

% --- 3. CLEAN UP AND INITIALIZE UART ---
objs = instrfind('Port', portName);
if ~isempty(objs), fclose(objs); delete(objs); end

s = serial(portName, 'BaudRate', baudRate, 'Terminator', 'CR/LF');
try
    fopen(s);
    flushinput(s);
    fprintf('>>> CONNECTED TO %s. WAITING FOR DATA...\n', portName);
catch
    error('ERROR: Cannot open port %s.', portName);
end

% --- 4. INITIALIZE DISPLAY INTERFACE ---
full_img_recon = zeros(32, 32);
hFig = figure('Name', 'BCS 32x32 Real-time Monitor: PSNR & Timing', 'Color', 'w', ...
              'Position', [50, 100, 1100, 550]);

% Subplot 1: Original Image
subplot(1,2,1); imagesc(img_gt, [0 1]); colormap gray; axis image;
title('Original Image (Ground Truth)'); xlabel('32x32 Pixels');

% Subplot 2: Reconstructed Image
subplot(1,2,2); hImg = imagesc(full_img_recon, [0 1]); colormap gray; axis image;
hTitle = title('FPGA Recovery: Waiting...'); 
hXLabel = xlabel({'Stitched from 4 blocks'; 'Total Time: 0.00 us'}); % Save xlabel handle

% Define Offsets for 4 blocks
offsets = [0, 0; 0, 16; 16, 0; 16, 16]; 
current_tile = 0;
block_times = zeros(1, 4);
total_32x32_time = 0;

% --- 5. MAIN EXECUTION LOOP ---
while ishandle(hFig)
    if s.BytesAvailable > 0
        line = fgetl(s);
        fprintf('%s\n', line); % Print log to Console
        
        % A. Tile ID Identification
        if ~isempty(strfind(line, 'CHAY KHOI'))
            tokens_tile = regexp(line, 'CHAY KHOI (\d+)', 'tokens');
            if ~isempty(tokens_tile)
                current_tile = str2double(tokens_tile{1}{1});
            end
        end
        
        % B. Extract individual block execution time: ">> Thoi gian khoi X: XXX.XX us"
        t_block_tokens = regexp(line, 'Thoi gian khoi \d+:\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        if ~isempty(t_block_tokens)
            block_times(current_tile) = str2double(t_block_tokens{1}{1});
        end
        
        % C. Extract TOTAL execution time: "TONG THOI GIAN PHUC HOI ANH 32x32: XXX.XX us"
        t_total_tokens = regexp(line, 'TONG THOI GIAN PHUC HOI ANH 32x32:\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        if ~isempty(t_total_tokens)
            total_32x32_time = str2double(t_total_tokens{1}{1});
            set(hXLabel, 'String', {sprintf('Stitched from 4 blocks (16x16)'); ...
                                    sprintf('Total HW Time: %.2f us', total_32x32_time)});
        end

        % D. Extract Pixel Data: | Lambda | Intensity
        tokens_px = regexp(line, '\|\s*(\d+)\s*\|\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        
        if ~isempty(tokens_px) && current_tile > 0
            lambda = str2double(tokens_px{1}{1});
            val    = str2double(tokens_px{1}{2});
            
            % Coordinate Mapping
            col_local = floor(lambda / 16);
            row_local = mod(lambda, 16);
            row_global = row_local + offsets(current_tile, 1) + 1;
            col_global = col_local + offsets(current_tile, 2) + 1;
            
            full_img_recon(row_global, col_global) = max(0, val);
            set(hImg, 'CData', full_img_recon);
            
            % PSNR Calculation
            mse = mean((img_gt(:) - full_img_recon(:)).^2);
            if mse > 0
                psnr_val = 10 * log10(1.0 / mse);
                set(hTitle, 'String', sprintf('FPGA Recovery (PSNR: %.2f dB)', psnr_val));
            end
            
            drawnow limitrate;
        end
    end
    pause(0.001);
end

% --- 6. TERMINATION ---
if exist('s', 'var'), fclose(s); delete(s); end
fprintf('\n>>> UART Connection Closed.\n');