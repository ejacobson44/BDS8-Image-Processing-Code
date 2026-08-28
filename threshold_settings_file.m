% text file for gated images 
% settings.select_txt = "Image Files for 15 minutes harveste report.txt";
settings.select_txt = "all";

% folder containing all images
settings.select_folder = "C:\Ethan!!!\DATA - 15_minute harvested\15 minutes harvested 1_20_images_20260424_1919_17";
settings.select_file = "C:\Ethan!!!\DATA - 15_minute harvested\15 minutes harvested 1_20.fcs"; 

settings.aspect_ratio = 0.73; % 2um
% settings.aspect_ratio = 0.5611; % 3um 


% [1,2,3,4,5,6] = [light loss, FSC, SSC, green, blue, red]

settings.selected_channel = 4;      % Channel to use (1–6)

settings.multiplier_large = 0.95; 
settings.multiplier_small = 1.1;
settings.norm = 1; 

settings.min_size = 10;              % Minimum object size (in pixels)

settings.max_segmented_objects = 4; 

settings.show_steps = false; 

settings.gated = false; 

settings.process_folder = true; 

settings.eccentricity = 0.4; 

settings.min_minor_axis_length_pixels = 8.33; 
settings.max_minor_axis_length_pixels = 30; 