%% ========================================================================
%  MONITORING AND COMPARISON SYSTEM FOR TILING 64x64 IMAGE RECONSTRUCTION (BCS OMP)
%  Version: 64x64 (16 blocks of 16x16) - MATLAB R2016a/b Compatible
%  Function: Receives 16 blocks of 16x16, compares with Ground Truth, computes real-time PSNR
%  ========================================================================

clc; clear; close all;

% --- 1. COM PORT CONFIGURATION ---
portName = 'COM4';  % <--- CHANGE YOUR COM PORT HERE
baudRate = 115200;

% --- 2. GENERATE ORIGINAL IMAGE (GROUND TRUTH) 64x64 ---
N_side = 64;
N_sub = 16;
img_gt = zeros(N_side, N_side);
num_blocks_per_side = N_side / N_sub; % 64/16 = 4

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


% --- 3. CLEAN UP AND INITIALIZE UART ---
% Clear any hung up connections
objs = instrfind('Port', portName);
if ~isempty(objs), fclose(objs); delete(objs); end

s = serial(portName, 'BaudRate', baudRate, 'Terminator', 'CR/LF');
try
    fopen(s);
    flushinput(s);
    fprintf('>>> CONNECTED TO %s. WAITING FOR 64x64 TILING DATA...\n', portName);
catch
    error('ERROR: Could not open port %s. Please close SDK Terminal!', portName);
end

% --- 4. INITIALIZE DISPLAY INTERFACE AND CALCULATE COORDINATES ---
full_img_recon = zeros(N_side, N_side);
hFig = figure('Name', 'BCS 64x64: Ground Truth vs FPGA Recovery', 'Color', 'w', ...
              'Position', [200, 200, 1000, 450]);

% Subplot 1: Original Image
subplot(1,2,1); 
imagesc(img_gt); colormap gray; axis image;
title('Original Image (64x64)'); 
xlabel('Ground Truth');

% Subplot 2: Reconstructed Image from FPGA
subplot(1,2,2); 
hImg = imagesc(full_img_recon); colormap gray; axis image;
hTitle = title('FPGA Recovery: Waiting...'); 
hXLabel = xlabel({'Stitched from 16 blocks'; 'Total Time: 0.00 us'}); % Save xlabel handle

% Super title for the entire Figure window
annotation('textbox', [0.35, 0.9, 0.3, 0.1], ...
    'String', '64x64 TILING REAL-TIME RECONSTRUCTION', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');


% =========================================================================
% CALCULATE OFFSETS IN ROW-MAJOR ORDER
% =========================================================================
offsets = zeros(16, 2);
tile_idx = 1;
for r = 1:num_blocks_per_side     % ROW LOOP: Scan row by row
    for c = 1:num_blocks_per_side % COLUMN LOOP: Scan from left to right
        offsets(tile_idx, 1) = (r-1)*N_sub; % Row coordinate (Y)
        offsets(tile_idx, 2) = (c-1)*N_sub; % Column coordinate (X)
        tile_idx = tile_idx + 1;
    end
end

current_tile = 0;
total_64x64_time = 0;

% --- 5. REAL-TIME DATA RECEPTION AND PSNR CALCULATION LOOP ---
while ishandle(hFig)
    if s.BytesAvailable > 0
        line = fgetl(s);
        fprintf('%s\n', line); % Print log to MATLAB Command Window
        
        % A. Current Tile ID Identification (Captures string "CHAY KHOI X / 16")
        if ~isempty(strfind(line, 'CHAY KHOI'))
            tokens_tile = regexp(line, 'CHAY KHOI (\d+)', 'tokens');
            if ~isempty(tokens_tile)
                current_tile = str2double(tokens_tile{1}{1});
            end
        end
		
        % C. Extract TOTAL execution time: "TONG THOI GIAN PHUC HOI ANH 64x64: XXX.XX us"
        t_total_tokens = regexp(line, 'TONG THOI GIAN PHUC HOI ANH 64x64:\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        if ~isempty(t_total_tokens)
            total_64x64_time = str2double(t_total_tokens{1}{1});
            set(hXLabel, 'String', {sprintf('Stitched from 16 blocks (16x16)'); ...
                                    sprintf('Total HW Time: %.2f us', total_64x64_time)});
        end
        
        % B. Extract Pixel Data: Captures string "| Lambda | Intensity Float"
        % Regex Explanation: Find '|' -> get integer -> find '|' -> get signed float
        tokens_px = regexp(line, '\|\s*(\d+)\s*\|\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        
        if ~isempty(tokens_px) && current_tile > 0 && current_tile <= 16
            lambda = str2double(tokens_px{1}{1});
            val    = str2double(tokens_px{1}{2});
            
            % Map Lambda (0->255) to Local (Row, Col) within 16x16 block
            col_local = floor(lambda / 16);
            row_local = mod(lambda, 16);
            
            % Map to 64x64 Global Coordinates
            row_global = row_local + offsets(current_tile, 1) + 1;
            col_global = col_local + offsets(current_tile, 2) + 1;
            
            % Update pixel (Filter negative values < 0 if necessary)
            full_img_recon(row_global, col_global) = max(0, val);
            set(hImg, 'CData', full_img_recon);
            
            % --- C. REAL-TIME PSNR CALCULATION ---
            mse = mean((img_gt(:) - full_img_recon(:)).^2);
            if mse > 0
                psnr_val = 10 * log10(1.0^2 / mse);
                % Update PSNR value to window title
                set(hTitle, 'String', sprintf('PSNR: %.2f dB', psnr_val));
            else
                set(hTitle, 'String', 'PSNR: Inf dB');
            end
            
            drawnow limitrate;
        end
    end
    pause(0.001);
end

% --- 6. TERMINATION ---
try
    fclose(s); delete(s);
    fprintf('\n>>> UART Connection Closed.\n');
catch
end