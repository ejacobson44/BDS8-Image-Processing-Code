%% Image Processing Code 
% =======================
% This script pulls and segments cytometer images from the BDS8 imaging
% cytomter. This is the main script. 


%% Structure: 
% 1. Load the folder holding images via the threshold_settings_file.m
% 2. For each image in the folder, create an object via the Image_Object class.
%    The image object stores each image with it's image ID, path and
%    channel. 
% 3. Each image object is then segmented. All calculations done are stored
%    with their parent image within the object. 
% 4. The 'Cell_Object' class creates additional objects for each area
%    segmented from the original image. A similar pipeline is implemented with
%    each object in the class 'Cell_Object' class containing it's parent image ID, 
%    cutouts of the segmented area and all subsiquent calculations. 
% 5. After all calculations are done, analysis is done by slicing through
%    either the cell or image object stacks using dot indexing. 


% clear the live enviornment between runs 
clear all; 
close all; 
clc; 

% diagnostic to track how long each run takes 
tic

% Ensure background worker pool is active before running calculations
if isempty(gcp('nocreate'))
    parpool();
end

% load the settings file
run("threshold_settings_file.m")


%% ====== Open image folder ====== 
image_root = settings.select_folder;   % folder where images are stored 


% If working of a specific subset of images gated in FlowJo set "all" to
% the name of the text file FlowJo export containng the list of gated image IDs
if settings.select_txt == "all" % all images in folder 
    all_files = dir(fullfile(image_root, '**', '*.tiff'));
    all_files = all_files(~[all_files.isdir]);


    % analyze all files in folder
    N = length(all_files);
    % analyze first N images in folder (for diagnostics) 
    N = 10;

    % If working off a specific subset of images gated in FlowJo
else
    text_file = settings.select_txt;
    all_lines = readlines(text_file);
    all_lines(all_lines == "") = [];
    N = length(all_lines);
end

%% ====== Load fcs data ======
[fcs_data, channel_names] = construct_fcs(settings);


%% ====== Construct first N images in folder ======
% load in each image object from the folder

for k = 1:N % for each image in the folder
    if settings.select_txt == "all" % if using all images in folder
        full_path = fullfile(all_files(k).folder, all_files(k).name); 
        disp("loading image: " + string(k))
    else 
        line1 = strtrim(all_lines(k)); 
        parts = split(line1, "\");
        fileName = parts(end);

        % If text file doesn't have paths, find where that file lives
        temp_find = dir(fullfile(image_root, '**', fileName));
        full_path = fullfile(temp_find(1).folder, temp_find(1).name);
    end
    
    % construct the image object 
    images(k) = Image_Object(k, full_path, settings.selected_channel);
end
disp(" end constructor ")


%% ===== Find min and max intenstiy across all images to set scale ====
% this is where images are loaded into memory
parfor k = 1:N
    % Load raw image on a dummy variable
    temp_obj = images(k).Ensure_Loading_Raw(); 
    
    % Calculate min and max intensity for each object
    temp_obj = temp_obj.Raw_Intensity();
    
    % 3. save those values to the real object
    images(k) = temp_obj;
end

% Slice all the local mins and maxes out of the object array
max_batch_intensity = [images.raw_max_intensity];
min_batch_intensity = [images.raw_min_intensity];

% Find the min and max intensity of the data set 
dataset_max = max(max_batch_intensity);
dataset_min = min(min_batch_intensity);

% Manually set max and min for a data set. 
% example values from 15 minute harvested data set: 
    % dataset_max =  1.342066407203674; 
    % dataset_min = -0.470862269401550; 


 

% Sliced layout necessary for tracking independent variables in parfor loops
cells_sliced = cell(1, N);

parfor x = 1:N
    %% ===== To Integrate data from the fcs files=====
  
    % update image object using the Get_FCS method. Select channel names.
    % See 'BDS8 Channel Names'  spreadsheet for a list of channel. 
        % images(x) = images(x).Get_FCS(fcsData, channel_names, 'Max Intensity (TFC eGFP)','SSC (Violet)-A', 'SSC (Violet)-H', 'SSC (Violet)-W');

    %% ===== Prepare the images for segmentiaton =====
    
    % Convert 16 bit images into 8 bit images setting the max and min
    % values to correspond to the global max and min of the data set. 
    images(x) = images(x).Convert_To_Uint8_Global(dataset_min, dataset_max); 

    % Calculate the pixel row intenstiy. This is used to seperate small
    % GUVs from large GUVs later on. 
    images(x) = images(x).Compute_Norm();

    % Method using imfinfo() to collect image meta data used for rescaling
    % none square pixels 
    images(x) = images(x).Get_Info();


    %% ===== Image Segmentiation =====
    % Guassian filter method applied to reduce noisy pixels 
    images(x) = images(x).Gaussian_Filter(); % smooth / convert to 8-bit
    
    % Calculate 2 Otsu thresholds 
    images(x) = images(x).Cast_Otsu(2); 
    
    % Option to resize image based on scale factor from meta data to
    % account for  none square pixels. This will interpolate using
    % imresize() and the bilinear interpolation to downscale the y-axis.
    % See README for more information in image stretching. 
    images(x) = images(x).Resize_Image(); 
    
    % 3. Threshold via Otsu depending on intensity (currently that's max
    % row sum, later will be on FCS data
    
    %% ===== Applying Threshold =====
    % different Otsu thresholds are applied to different sized objects.
    % Each Otus threshold applied cna be scaled independently in the
    % threshold_settings file. 

    % The l infinity norm is the max row intensity 
    if images(x).linf_norm > settings.norm
        % lower threshold applied to larger objects 
        images(x) = images(x).Apply_Threshold(1,settings.multiplier_large);
    else
        % higher threshold applied to smaller objects 
        images(x) = images(x).Apply_Threshold(2,settings.multiplier_small);
    end

    % The imclose() function is used to fill in large holes in
    % segmentation. 
    images(x) = images(x).Crescent(2); 

    % Fill in small areas surrounded by positive pixels 
    images(x) = images(x).Fill_Holes();

    % Remove small islands of pixels. The number of pixels that constitutes an island can be set in the 'threhsold_settings' file 
    images(x) = images(x).Remove_Islands(settings.min_size);
    
    % Displays the image being segmented. Can be turned off to improve
    % performace. 
    disp("Segmenting image #" + string(x))

    %% ===== Measure properties =====
    % Run region props library on binary and 8-bit images to calculate
    % image properties. 
    images(x) = images(x).Measure_Objects();
    

    %% ===== Construct Cells =====
    % Cells are square cutouts of objects segmented in original images.
    % Each segmented element from an image is assigned to the cell class.
    % Similar to images the cell objects hold the cutouts and all
    % subsiquently calculated imaing features. 
    
    % Initiate the method in the image class to construct cell objects for
    % each segmented element. 
    new_batch = images(x).Construct_Cells();
    
    % Since there can be multiple cells in an image a new loop is used to
    % calculate features of each cell object isolated from the image
    if length(new_batch) >= 1
        for b = 1:length(new_batch)
            % method to calculate coefficent of variation for each object
            new_batch(b) = new_batch(b).Calculate_CV(); 

            % 'GUVness' is a number between 0 and ~3 ranking how hollow the
            % object appears. (see README for more details) 
            new_batch(b) = new_batch(b).Calculate_GUVness();
            
            % Option to wipe image arrays from RAM before loading next
            % image (Note: If generating cell walls this should be
            % disabled) 
                % new_batch(b) = new_batch(b).Clear_Heavy_Data();
        end
    else
        disp("no objects detected")
    end


    % Add new cell objects to list
    cells_sliced{x} = new_batch; 
    
    % Option to clear image matricies from RAM after cells are constructed
    % (Note: If generating image walls this should not be enabeled.) 
    % images(x) = images(x).Clear_Heavy_Data; 
   
end

disp("end segmentation")



% Parallel results unpacking
cells = [cells_sliced{:}]; 



%% ===== Additional data cleaning steps analysis ===== 

% Only include segmented objects with a low eccentricity
% Eccentricity can be set in 'threshold_settings'
circles = arrayfun(@(c) c.stats.Eccentricity, cells);
valid_circles_mask = circles > settings.eccentricity; % 0.4
cells = cells(valid_circles_mask);

% Seperate objects based on size 
minor_axes = arrayfun(@(c) c.stats.MinorAxisLength, cells);
minor_axis_gate_mask = (minor_axes > settings.minor_axis_length_pixels);
cells_size_gated = cells(minor_axis_gate_mask);

% The CV values for cells larger than the minor axis length 
all_gated_CVs = [cells_size_gated.internal_CV];

%% ===== Data Analysis ===== 






%% ===== Temporary Functions ===== % 


toc