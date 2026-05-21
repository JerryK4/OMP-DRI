%% SCRIPT TO STITCH FOUR 16x16 BLOCKS INTO A 32x32 IMAGE AND COMPARE PSNR
clc; clear; close all;

% =========================================================================
% 1. CREATE ORIGINAL IMAGE (GROUND TRUTH) 32x32 - SYMMETRIC GEOMETRIC PATTERN
% Each 16x16 block has a unique motif to verify Tiling accuracy
% =========================================================================
N_side = 32;
img_gt = zeros(N_side, N_side);

% --- COMPONENT 1: Solid 2x2 square core at center (Intersection of 4 blocks) ---
% Each block will receive exactly 1 pixel at the center of the large image
img_gt(16:17, 16:17) = 1.0; 

% --- COMPONENT 2: Hollow Octagon Frame (Cross-border connections) ---
% Top horizontal edge (crosses columns 16-17)
img_gt(10, 14:19) = 0.8; % 3 pixels in block 1, 3 pixels in block 2
% Bottom horizontal edge (crosses columns 16-17)
img_gt(23, 14:19) = 0.8; % 3 pixels in block 3, 3 pixels in block 4
% Left vertical edge (crosses rows 16-17)
img_gt(14:19, 10) = 0.8; % 3 pixels in block 1, 3 pixels in block 3
% Right vertical edge (crosses rows 16-17)
img_gt(14:19, 23) = 0.8; % 3 pixels in block 2, 3 pixels in block 4

% --- COMPONENT 3: Symmetrical highlights in 4 corners ---
img_gt(5, 5)   = 0.6;  % Block 1 corner
img_gt(5, 28)  = 0.6;  % Block 2 corner
img_gt(28, 5)  = 0.6;  % Block 3 corner
img_gt(28, 28) = 0.6;  % Block 4 corner

% =========================================================================
% 2. TILING ADDRESS CONFIGURATION (TILING MAP)
% =========================================================================
tile_offsets = [
     1,  1;   % Tile 1: Top-Left
     1, 17;   % Tile 2: Top-Right
    17,  1;   % Tile 3: Bottom-Left
    17, 17    % Tile 4: Bottom-Right
];

img_recon = zeros(N_side, N_side);

% =========================================================================
% 3. READ DATA FROM 4 .TXT FILES
% =========================================================================
for t = 1:4
    filename = sprintf('omp_reconstruction_results_%d.txt', t);
    if ~exist(filename, 'file')
        warning('File %s not found', filename);
        continue;
    end
    
    fprintf('Reading %s...\n', filename);
    fid = fopen(filename, 'r');
    
    % Create temporary matrix for 16x16 block
    sub_img_vec = zeros(16*16, 1);
    
    % Read line by line
    while ~feof(fid)
        tline = fgetl(fid);
        % Regex to extract Lambda and Val (Float)
        % Format: Index | Lambda | Hex | Float
        tokens = regexp(tline, '^\s*\d+\s*\|\s*(\d+)\s*\|\s*[0-9a-fA-F]+\s*\|\s*([-+]?[0-9]*\.?[0-9]+)', 'tokens');
        
        if ~isempty(tokens)
            lambda = str2double(tokens{1}{1});
            val    = str2double(tokens{1}{2});
            
            % Assign value to correct position in 256-element vector
            % (Add 1 because MATLAB uses 1-based indexing)
            if lambda < 256
                sub_img_vec(lambda + 1) = val;
            end
        end
    end
    fclose(fid);
    
    % Convert 1D block back to 2D 16x16
    % Note: Reshape using [16,16] because image was column-vectorized in OMP
    sub_img_2d = reshape(sub_img_vec, [16, 16]);
    
    % Stitch block into 32x32 total image
    row_start = tile_offsets(t, 1);
    col_start = tile_offsets(t, 2);
    img_recon(row_start : row_start+15, col_start : col_start+15) = sub_img_2d;
end

% Filter out negative noise (due to fixed-point calculations)
img_recon = max(0, img_recon);

% =========================================================================
% 4. PSNR CALCULATION AND VISUALIZATION
% =========================================================================
mse = mean((img_gt(:) - img_recon(:)).^2);
if mse > 0
    psnr_val = 10 * log10(1.0 / mse);
else
    psnr_val = Inf;
end

fprintf('\n>>> PSNR between Original and stitched FPGA Image: %.2f dB\n', psnr_val);

% Display
figure('Color', 'w', 'Position', [100, 100, 900, 400]);

subplot(1, 2, 1);
imagesc(img_gt); colormap gray; axis image;
title('Original Image (Ground Truth) 32x32');


subplot(1, 2, 2);
imagesc(img_recon); colormap gray; axis image;
title(['Reconstructed Image from FPGA (Tiling)', char(10), 'PSNR = ', num2str(psnr_val), ' dB']);
