% ===== Generate_Image_Wall() - function description ====

% Generates an image wall of selected images
% image_objects: pass the image object array
% image_type: dot index where the image property lives as a string. Example, pass the .raw = 'raw_image'
% index_list: an array of integers that corresponds to the index of which
% objects in the image_object class get selected. for example: index_list =
% [1,4,5] will load images(1,4, and 5)
% wall_title: string with wall title
% excluded_IDs: list of image_ID strings which get crossed out on the wall.
% if none set to [];
% example call for first 100 raw images with none crossed out
%{
wall_list = 1:N; 
rejected_IDs = []; 
Generate_Image_Wall(images, 'raw_image', wall_list, "thresholded images", rejected_IDs);
%}
% for a random list:
% K = 100;
% wall_list = randperm(N, K);
% randperm(N,K) returns a list of K unique integers randomly selected from
% 1 to N

function Generate_Image_Wall(image_objects, image_type, index_list, wall_title, excluded_IDs)
% 1. Setup
num_to_show = length(index_list);
thumbs = cell(1, num_to_show);
target_width = 104;

% 2. Loop through the specific indices provided
for i = 1:num_to_show
    idx = index_list(i);
    current_ID = image_objects(idx).image_ID;
    img = image_objects(idx).(image_type);

    % --- PRE-CONVERSIONS BEFORE COLOR ANNOTATION ---
    if islogical(img)
        % For binary masks (current_image), map true to 255
        img = uint8(img) * 255;

    elseif isa(img, 'uint8')
        % If it's already uint8_image, leave it alone! It is already globally scaled.
        img = img;

    elseif isa(img, 'double') && ~isempty(img)
        % Only do local scaling if it's a raw 32-bit double unscaled image
        img_min = min(img(:));
        img_max = max(img(:));
        if img_max > img_min
            img = uint8(255 * (img - img_min) / (img_max - img_min));
        else
            img = uint8(img);
        end
    end

    % --- Resize thumbnails and Annotate ---
    if ~isempty(img)
        scale = target_width / size(img, 2);
        thumb = imresize(img, scale);

        % Convert to RGB color workspace so text/shapes display in color
        if size(thumb, 3) == 1
            thumb = cat(3, thumb, thumb, thumb);
        end

        % Check if this ID is in the rejected list
        if ismember(current_ID, excluded_IDs)
            [h, w, ~] = size(thumb);
            lines = [0, 0, w, h; 0, h, w, 0];
            thumb = insertShape(thumb, 'Line', lines, 'LineWidth', 3, 'Color', 'red', 'Opacity', 0.6);
        end

        % Add ID Label
        txt = "ID: " + string(current_ID);
        thumbs{i} = insertText(thumb, [5, 5], txt, 'FontSize', 12, 'BoxOpacity', 0.4);
    else
        thumbs{i} = zeros(target_width, target_width, 3, 'uint8');
    end
end

% 3. Create the Montage
figure('Name', wall_title, 'Color', 'w');

% Because the tiles are true RGB color fields, montage will safely use [0, 255] implicitly.
montage(thumbs, 'Size', [NaN, 10], 'ThumbnailSize', []);

title(wall_title + " (n=" + num_to_show + ")");
end