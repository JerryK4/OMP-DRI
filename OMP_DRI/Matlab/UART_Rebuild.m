%% ========================================================================
%  TERMINAL MONITORING SYSTEM AND REAL-TIME DRI IMAGE RECONSTRUCTION COMPARISON
%  Version: Displays PSNR and Execution Time (us) - R2016a/b Compatible
%  ========================================================================

clc; clear; close all;

% --- 1. COM PORT CONFIGURATION ---
portName = 'COM4';  
baudRate = 115200;

% --- 2. GENERATE ORIGINAL IMAGE (GROUND TRUTH) 16x16 ---
img_gt = zeros(16, 16);
img_gt(4, 4) = 1.0;         
img_gt(4, 5) = 0.6; img_gt(5, 4) = 0.6; 
img_gt(12:13, 12:13) = 0.8; 
img_gt(8, 8) = 0.9;         
img_gt(7, 8) = 0.5; img_gt(9, 8) = 0.5;
img_gt(8, 7) = 0.5; img_gt(8, 9) = 0.5;


% --- 3. CLEAN UP COM PORT ---
objs = instrfind('Port', portName);
if ~isempty(objs), fclose(objs); delete(objs); end

% --- 4. INITIALIZE UART CONNECTION ---
s = serial(portName, 'BaudRate', baudRate, 'Terminator', 'CR/LF');
try
    fopen(s);
    flushinput(s);
    fprintf('>>> CONNECTED TO %s. WAITING FOR DATA FROM FPGA...\n', portName);
catch
    error('ERROR: Could not open %s. Please close other Serial Terminals!', portName);
end

% --- 5. INITIALIZE GRAPHICAL INTERFACE ---
img4  = zeros(4, 4); img8  = zeros(8, 8); img16 = zeros(16, 16);
hFig = figure('Name', 'DRI Real-time Monitor: PSNR & Hardware Timing', ...
              'Color', 'w', 'Position', [50, 150, 1400, 450]);

% Original Image
subplot(1,4,1); imagesc(img_gt); axis image; colormap gray; 
title('Original Image', 'FontWeight', 'bold'); xlabel('Ground Truth');

% Stage 4x4
subplot(1,4,2); h4_plot = imagesc(zeros(16,16)); axis image; 
title('Level 1 (4x4)'); hX4 = xlabel({'PSNR: N/A'; 'Time: --- us'});

% Stage 8x8
subplot(1,4,3); h8_plot = imagesc(zeros(16,16)); axis image; 
title('Level 2 (8x8)'); hX8 = xlabel({'PSNR: N/A'; 'Time: --- us'});

% Stage 16x16
subplot(1,4,4); h16_plot = imagesc(zeros(16,16)); axis image; 
title('Level 3 (16x16)'); hX16 = xlabel({'PSNR: N/A'; 'Time: --- us'});

current_stage = 0;
stage_psnr = [0, 0, 0]; % Store PSNR for 3 stages

% --- 6. MAIN EXECUTION LOOP ---
while ishandle(hFig)
    if s.BytesAvailable > 0
        line = fgetl(s); 
        fprintf('%s\n', line); 
        
        % A. Stage Identification
        if ~isempty(strfind(line, 'CHAY STAGE 1')),     current_stage = 1; 
        elseif ~isempty(strfind(line, 'CHAY STAGE 2')), current_stage = 2; 
        elseif ~isempty(strfind(line, 'CHAY STAGE 3')), current_stage = 3; 
        end
        
        % B. Extract Execution Time (Pattern matching: "Thoi gian thuc thi: XXX.XX us")
        time_tokens = regexp(line, 'Thoi gian thuc thi:\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        if ~isempty(time_tokens)
            exec_time = str2double(time_tokens{1}{1});
            
            % Update the corresponding time label for the current stage
            psnr_str = 'PSNR: N/A'; 
            if current_stage == 3 && stage_psnr(3) > 0
                psnr_str = sprintf('PSNR: %.2f dB', stage_psnr(3));
            end
            
            new_label = {psnr_str; sprintf('Time: %.2f us', exec_time)};
            if current_stage == 1,     set(hX4, 'String', new_label);
            elseif current_stage == 2, set(hX8, 'String', new_label);
            elseif current_stage == 3, set(hX16, 'String', new_label);
            end
        end

        % C. Extract Pixel Data: | Lambda | Val
        tokens = regexp(line, '\|\s*(\d+)\s*\|\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        if ~isempty(tokens)
            lambda = str2double(tokens{1}{1});
            val    = str2double(tokens{1}{2});
           
            if current_stage == 1 && lambda < 16
                img4(lambda + 1) = val;
                
                % ENHANCE CONTRAST FOR 4x4 DISPLAY
                img_disp = img4;
                max_v = max(img_disp(:));
                if max_v > 0, img_disp = (img_disp / max_v) .^ 2.0; end
                
                set(h4_plot, 'CData', imresize(img_disp, [16 16], 'nearest'));
                
            elseif current_stage == 2 && lambda < 64
                img8(lambda + 1) = val;
                
                % ENHANCE CONTRAST FOR 8x8 DISPLAY
                img_disp = img8;
                max_v = max(img_disp(:));
                if max_v > 0, img_disp = (img_disp / max_v) .^ 2.0; end
                
                set(h8_plot, 'CData', imresize(img_disp, [16 16], 'nearest'));
                
            elseif current_stage == 3 && lambda < 256
                img16(lambda + 1) = val;
                set(h16_plot, 'CData', img16);
                
                % Calculate PSNR for Stage 3
                mse = mean((img_gt(:) - img16(:)).^2);
                if mse > 0
                    stage_psnr(3) = 10 * log10(1 / mse);
                end
                
                % UPDATE LABELS (Retain execution time if already captured to avoid displaying 'Calculating')
                current_label = get(hX16, 'String');
                if iscell(current_label) && ~isempty(strfind(current_label{2}, 'us'))
                    % If time data already exists, only update PSNR
                    set(hX16, 'String', {sprintf('PSNR: %.2f dB', stage_psnr(3)); current_label{2}});
                else
                    % If time data is not yet available, show Calculating
                    set(hX16, 'String', {sprintf('PSNR: %.2f dB', stage_psnr(3)); 'Time: Calculating...'});
                end
            end
            drawnow limitrate;
        end
    end
    pause(0.001); 
end

% --- 7. CLEANUP AND TERMINATION ---
if exist('s', 'var'), fclose(s); delete(s); end
fprintf('\n>>> UART CONNECTION CLOSED.\n');