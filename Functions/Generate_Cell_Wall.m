function Generate_Cell_Wall(cell_array, wall_title, image_type, should_save)
% 1. Setup & Baseline Validation
num_to_show = length(cell_array);
if num_to_show == 0
    disp("No cells found matching criteria for: " + wall_title);
    return;
end

% Default to standard global uint8 behavior if no type is passed
if nargin < 3 || isempty(image_type)
    image_type = 'uint8_image';
end

% Default should_save to false if not provided
if nargin < 4
    should_save = false;
end

% Dynamic Grid Dimensions (Scales up to a square configuration for 1000 cells)
max_cells = 100;
max_display = min(num_to_show, max_cells);
cols = round(sqrt(max_cells)); % Sets grid columns to 32

% Pad out the cell array so it fills the grid evenly
rem_tiles = mod(max_display, cols);
total_tiles = max_display;
if rem_tiles ~= 0
    total_tiles = max_display + (cols - rem_tiles);
end

thumbs = cell(1, total_tiles);
box_dim = 104;

% 2. Loop through and process images based on the requested format
for i = 1:total_tiles
    % Base charcoal frame background
    canvas = ones(box_dim, box_dim, 'uint8') * 20;

    if i <= max_display
        current_cell = cell_array(i);
        raw_cutout = current_cell.cutout_uint8; % Grab your 8-bit matrix

        if ~isempty(raw_cutout)
            % --- SELECT THE SCALING PATHWAY ---
            if strcmp(image_type, 'dynamic_8bit') && ~isempty(raw_cutout)
                % Option A: Stretch the 8-bit values locally to maximize contrast visibility
                c_min = double(min(raw_cutout(:)));
                c_max = double(max(raw_cutout(:)));

                if ~isempty(c_max) && ~isempty(c_min) && (c_max > c_min)
                    scaled_cutout = uint8(255 * (double(raw_cutout) - c_min) / (c_max - c_min));
                else
                    scaled_cutout = raw_cutout;
                end
            else
                % Option B: Keep your exact original global 8-bit limits (accurate but faint)
                scaled_cutout = raw_cutout;
            end

            % --- Size Management & Positioning ---
            [cutout_h, cutout_w] = size(scaled_cutout);

            if cutout_h > box_dim
                scaled_cutout = scaled_cutout(1:box_dim, :);
                cutout_h = box_dim;
            end
            if cutout_w > box_dim
                scaled_cutout = scaled_cutout(:, 1:box_dim);
                cutout_w = box_dim;
            end

            row_start = floor((box_dim - cutout_h) / 2) + 1;
            col_start = floor((box_dim - cutout_w) / 2) + 1;
            row_end = row_start + cutout_h - 1;
            col_end = col_start + cutout_w - 1;

            canvas(row_start:row_end, col_start:col_end) = scaled_cutout;

            % --- MULTI-LINE TEXT OVERLAY  ---
            full_id = string(current_cell.parent_image_ID);
            if strlength(full_id) >= 8
                short_id = extractAfter(full_id, strlength(full_id) - 8);
            else
                short_id = full_id;
            end

            CV_value = 0;
            if ~isempty(current_cell.stats) && isfield(current_cell.stats, 'MeanIntensity')

                CV_value = current_cell.internal_CV;
            end


            intensity_val = current_cell.stats.MeanIntensity;
            lam = current_cell.GUVness;
            size_val = current_cell.stats.MinorAxisLength;

            % Create a stacked 2-line string showing sliced ID and raw mean intensity
            % txt = sprintf('ID:%s\n   Lam:%.1f\n   Int:%.1f', short_id, lam);


            txt = sprintf('ID:%s\n Lam:%.2f\n CV:%.2f\n Ints:%.2f\n MiAxL:%.2f', short_id, lam, CV_value, intensity_val, size_val);

            % =============================================================
            % MODIFIED TEXT OVERLAY ENGINE ONLY
            % =============================================================
            % 1. Upscale canvas by exactly 4x using 'nearest' neighbor.
            canvas_high_res = imresize(canvas, 4, 'nearest');

            % 2. Insert text onto the high-res canvas (Position and Font scaled 4x)
            temp_text_img = insertText(canvas_high_res, [4, 4], txt, 'FontSize', 24, 'BoxOpacity', 0.6, ...
                'TextColor', 'white', 'BoxColor', 'black');

            % 3. Save the crisp grayscale tile directly back into the thumbs cell array
            thumbs{i} = temp_text_img(:, :, 1);
            % =============================================================
        else
            % Match scaled dimensions for empty tiles
            thumbs{i} = imresize(canvas, 4, 'nearest');
        end
    else
        % Match scaled dimensions for empty tiles
        thumbs{i} = imresize(canvas, 4, 'nearest');
    end
end

% 3. Render the Montage Grid (Locked to [0, 255] spectrum)
fig = figure('Name', wall_title, 'Color', 'w');
set(fig, 'Position', [100, 100, 1250, 750]);
montage(thumbs, 'Size', [NaN, cols], 'DisplayRange', [0, 255], 'ThumbnailSize', []);
title(wall_title + " (Showing " + max_display + " of " + num_to_show + " cells)");

    
    if should_save
        % Convert the wall title to a safe, clean string for filename saving
        safe_title = regexprep(wall_title, '[^a-zA-Z0-9_-]', '_');
        filename = safe_title + ".png";
        
        % Export the montage figure at 1500 DPI resolution
        exportgraphics(fig, filename, 'Resolution', 1000);
        fprintf('Cell Wall montage successfully saved to disk as: %s\n', filename);
    end
end
