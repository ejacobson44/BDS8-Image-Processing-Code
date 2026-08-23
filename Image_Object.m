%% ===== Image Class ===== 
% This class is used to hold raw images and all calculations made from them
% Each image object holds a single channel of the original 6 channel tiff



classdef Image_Object 

    %% ===== Class Properties =====
    properties 

        % constructor properties 
        order_loaded  % index value from for loop used to assign images to class 
        image_path    % the path where the image is located
        image_ID      % the 8 digit tail identifier assigned to each .tiff image by the cytometer
        image_channel % The channel the image belongs to ( configured in the 'threshold settings' file) 

        % meta data 
        info          % the meda data from the 16 bit tiff obtained using iminfo() 
        scale_factor  % pixelsX/pixelsY (from meta data for scaling)
        y_normalized  % what the y axis is scaled to 
        aspect_ratio  % option to manually set aspect ratio instead of calculating from meta data


        % load image 
        raw_image     % raw 16-bit tiff on the selected channel 
        uint8_image   % 8 bit conversion of the original tiff using global max and min

        % calculated properties 

            % Properties calculated from the raw image 
            l1_norm
            l2_norm
            linf_norm % used to differentiate small objects from large objects before segmentation

            % intensity values for global scaling 
            raw_max_intensity 
            raw_min_intensity
            uint8_max_intensity
            uint8_min_intensity
      
            % 8-bit image 
            otsu_thresholds        % vector that can hold multiple Otsu thresholds 
            otsu_applied           % the threshold that was applied in segmentation on this specific image

            % binary image
            stats                  % struct of calculated properties from the region props matlab library 
            num_segmented_objects  % number of objects isolated from the image after segmentation

            image_empty = false; 


        % Stores the current image as it is passed through the segmentation pipeline 
        current_image 


        % integrate .fcs files 
        fcs_data = table(); % empty MATLAB table to store fcs data for the image
    end 




%% ===== Class Methods =====


%% CONSTRUCTOR:  
    methods 
        %% CONSTURCTOR METHODS: 
        % constructor create image object and define base values
        function obj = Image_Object(index_number, image_path, image_channel)
            % store values passed in Image_Processing_Code to their
            % appropriate properties
            obj.order_loaded = index_number; 
            obj.image_path = image_path; 
            obj.image_channel = image_channel; 

            % Call method to extract the imageID from the path 
            obj.image_ID = obj.Extract_Image_ID();
        end
        
        %% ===== Method to extract image ID from PATH =====  
        function id = Extract_Image_ID(obj)
            parts = split(obj.image_path, "\");
            fileName = parts(end);
            x = extractBetween(fileName, "_", ".tiff");
            i = char(x);
            l = strlength(i);
            id = i(l-7:l); % take end of string after parcing 
        end
        
        
        
    %% LOADING DATA: 
        
        %% ===== Load_Image =====
        % Load the image into memory 
        function obj = Load_Image(obj)
            if isnumeric(obj.image_channel) % make sure the channel is defined correctly (1-6) 
                temp = imread(obj.image_path, 'Index', obj.image_channel);
            else
                % If it's single read the first image available
                temp = imread(obj.image_path);
            end
            % load in 16-bit image
            obj.raw_image = double(temp);
        end

        %% ===== Get_Info ===== 
        function obj = Get_Info(obj)
            obj.info = imfinfo(obj.image_path); % matlab function that pulls meta data 
        end 

        %% ===== Get_FCS ===== 
        % get fcs data for the current image 
        function obj = Get_FCS(obj, fcsData, channel_names, varargin)
            % If the internal table is empty, build and save it
            if isempty(obj.fcs_data)
                [isValid, channel_indices] = ismember(varargin, channel_names);
                
                if ~all(isValid)
                    missing = varargin(~isValid);
                    error('The following requested channels do not exist in the FCS file: %s', ...
                        strjoin(missing, ', '));
                end
                
                % Grab row matching the loop sequence order
                filtered_values = fcsData(obj.order_loaded, channel_indices);
                
                % Save the mini-table directly to the object property
                obj.fcs_data = table(filtered_values', ...
                    'RowNames', varargin, ...
                    'VariableNames', {'Value'});
            end
        end
        
        

        %% IMAGE TRANSFORMATIONS: 
        % Methods that effect the entire image matrix for 8bit or raw
        % images

        %% ===== Convert_To_Uint8_Global ===== 
        % Conver the 16 bit image into 8 bit using the max and min
        % intensitys passed to the function in the Image_Processing_Code
        function obj = Convert_To_Uint8_Global(obj, global_min, global_max)
            obj = obj.Ensure_Loading_Raw();

            % Store the scaled bounds on the object for your records
            obj.uint8_min_intensity = min(obj.raw_image, [], 'all');
            obj.uint8_max_intensity = max(obj.raw_image, [], 'all');
            
            % convert based on global min and max
            if global_max > global_min
                % Map across the 0-255 scale using the entire dataset's limits
                obj.uint8_image = uint8(255 * (obj.raw_image - global_min) / (global_max - global_min));
            else
                obj.uint8_image = uint8(obj.raw_image);
            end

            obj.current_image = obj.uint8_image;
        end

        %% ===== Convert_To_Uint8 ===== 
        % Converts 16 bit image into 8 bit using the max and min intensity
        % of the 16 bit image. This is an old method and should not be used
        %{
        function obj = Convert_To_Uint8(obj)
            obj = obj.Ensure_Loading_Raw();

            % Find the max and min intensity of the image
            img_min = min(obj.raw_image(:));
            img_max = max(obj.raw_image(:));

            if img_max > img_min
                % Map the raw data safely across the 0-255 scale
                obj.uint8_image = uint8(255 * (obj.raw_image - img_min) / (img_max - img_min));
            else
                obj.uint8_image = uint8(obj.raw_image); % if all pixels have the same value
            end
            
            % update the current image with the 8 bit version for further
            % analysis 
            obj.current_image = obj.uint8_image;
        end
        %}

         %% ===== Resize_Image ===== 
        function obj = Resize_Image(obj)
            obj = obj.Ensure_Data_Loaded(); % make sure the data is loaded
            
            % calculate the scale factor from image meta data 
            obj.scale_factor = (obj.info(obj.image_channel).XResolution / obj.info(obj.image_channel).YResolution);

            % option to set the scale factor manually 
            % obj.scale_factor = obj.aspect_ratio; 

            % scale the original image height to match the height of meta
            % data 
            obj.y_normalized = round(obj.info(obj.image_channel).Height * obj.scale_factor);

            % update the current image with the resized image 
            obj.current_image = imresize(obj.current_image, [obj.y_normalized, obj.info(obj.image_channel).Width], 'bilinear');

            % Resize 8 bit image
            obj.uint8_image =  imresize(obj.uint8_image, [obj.y_normalized, obj.info(obj.image_channel).Width], 'bilinear');            
        end 

        %% ===== Gaussian_Filter =====
        function obj = Gaussian_Filter(obj)
            obj.current_image = imgaussfilt(obj.current_image);
        end

        

        %% CALCULATED IMAGE FEATURES: 
        % Methods that calculate properties from the image

        %% ===== Raw_Intensity ==== 
        % Find the max and min pixel intenstiy for 8bit conversion 
        function obj = Raw_Intensity(obj)
            obj.raw_max_intensity = max(obj.raw_image, [], 'all'); 
            obj.raw_min_intensity = min(obj.raw_image, [], 'all');
        end

        %% ===== Compute_Norm ===== 
        % find the matrix norms of the image. Matrix norms can be used to differnetiate the size of objects in an 
        % image before applying thresholds. 
        function obj = Compute_Norm(obj)
            obj = obj.Ensure_Loading_Raw(); 

            % obj.l1_norm = norm(obj.raw_image, 1); 
            % obj.l2_norm = norm(obj.raw_image, 2); 
            obj.linf_norm = norm(obj.raw_image, inf); % infinity norm = sum (row intenstiy) 
        end

        %% ===== Cast_Otsu ==== 
        % calculate Otsu thresholds for the image 
        function obj = Cast_Otsu(obj,num) % num of thresholds
            obj.otsu_thresholds = multithresh(obj.current_image, num); 
        end

        %% ===== Measure_Objects ===== 
        % Measure image properties. This method defines the cutouts used for cell class 
        function obj = Measure_Objects(obj)
            % call matlab's region props library to measure image
            % properties based on segmented and 8bit image
            regions = regionprops(obj.current_image, obj.uint8_image, 'BoundingBox',...
                'Image', 'MajorAxisLength', 'MinorAxisLength', 'Orientation', ...
                'Circularity', 'Eccentricity');
            obj.image_empty = isempty(regions);

            obj.stats = regions; % BoundingBox = [x, y, width, height] % the first object inx => largest
            obj.num_segmented_objects = length(regions);
        end



        %% SEGMENTATION: 
        % Methods that are applied to create or operate on binary image

        %% ===== Apply_Threshold ===== 
        % Apply previously calculated Otsu threshold to create binary image
        % 
        function obj = Apply_Threshold(obj, index, multiplier) % Apply the threshold. inputs; index = index of Otsu vector 
            
            % Out of bounds conditions
            if isempty(obj.otsu_thresholds) 
                error("You CANNOT apply thresholds before defining them.")
            end 

            max_index = length(obj.otsu_thresholds);
            if index < 1 || index > max_index
                error("Threshold index %d is out of range. Valid range is 1 to %d.", ...
                    index, max_index);
            end
            
            % Apply threshold to image
            obj.current_image = obj.current_image > obj.otsu_thresholds(index) * multiplier; 
            % Update applied threhsold property 
            obj.otsu_applied = obj.otsu_thresholds(index) * multiplier; 
        end
        
        %% ===== Crescent =====
        % fill in half moon segmentations
        function obj = Crescent(obj, n)
            se = strel('disk',n);
            obj.current_image = imclose(obj.current_image, se); 
        end 

        %% ===== Fill_Holes =====
        function obj = Fill_Holes(obj)
            obj.current_image = imfill(obj.current_image, 'holes');
        end 
        
        %% ===== Remove_Island ===== 
        % Remove pixel islands smaller than size defined in 'threshold_settings' 
        function obj = Remove_Islands(obj,min_size) % size of islands deleted
            obj.current_image = bwareaopen(obj.current_image, min_size);
        end 

        %% ===== Construct_Cells =====
        % cells are the individual cutouts of segmented objects from each
        % image. Each cell object is derived from the 8bit image
        function cell_array = Construct_Cells(obj)
            cell_array = Cell_Object.empty; % pre alocate memory for loops
            
            % Get the overall boundaries of the image frame
            [max_rows, max_cols] = size(obj.uint8_image);
            
            for k=1:length(obj.stats)
                % assign calcualted stats to the cell objects as they're created a
                seg = obj.stats(k);

                % Define the region with a 2-pixel outer buffer on edges
                r1 = max(1, floor(seg.BoundingBox(2)) - 2);
                c1 = max(1, floor(seg.BoundingBox(1)) - 2);

                % Ensure r2 and c2 also include the 2-pixel buffer and stay inside frame limits
                r2 = min(max_rows, r1 + round(seg.BoundingBox(4)) + 3);
                c2 = min(max_cols, c1 + round(seg.BoundingBox(3)) + 3);

                % Create the raw 8-bit image cutout
                cutout_uint8 = obj.uint8_image(r1:r2, c1:c2);

                % Generate a blank global canvas for this specific object's mask
                global_mask_canvas = false(max_rows, max_cols);
                
                % Determine the exact global coordinates of the unpadded seg.Image
                native_mask = seg.Image;
                
                % Use max(1, ...) to handle cells hitting the absolute 0-pixel border edge
                m_r1 = max(1, floor(seg.BoundingBox(2)));
                m_c1 = max(1, floor(seg.BoundingBox(1)));
                
                % Set up ending coordinates based on the actual size of the mask matrix
                m_r2 = min(max_rows, m_r1 + size(native_mask, 1) - 1);
                m_c2 = min(max_cols, m_c1 + size(native_mask, 2) - 1);
                
                % Ensure sizes match up precisely before slicing out from the canvas
                mask_sub_rows = 1:(m_r2 - m_r1 + 1);
                mask_sub_cols = 1:(m_c2 - m_c1 + 1);
                
                % Place the native mask onto the global canvas 
                global_mask_canvas(m_r1:m_r2, m_c1:m_c2) = native_mask(mask_sub_rows, mask_sub_cols);
                
                % Slice the final cutout mask using the EXACT same indices as the raw image
                cutout_mask = global_mask_canvas(r1:r2, c1:c2);

                % Construct the Cell Object using the mask
                cell_array(k) = Cell_Object(obj.image_ID, seg, k, cutout_uint8, cutout_mask);

            end
        end



        %% DEPENDANCY METHODS: 
        % Methods that make sure data is loaded before being used for
        % calulations 

        %% ===== Ensure_Data_Loaded =====
        % Make sure the meta data is loaded before image is re-scaled
        function obj = Ensure_Data_Loaded(obj)
            if isempty(obj.info)
                obj = obj.Get_Info();
            end
        end

        %% ===== Ensure_Loading_Raw ===== 
        % Make sure the raw image is loaded before doing calculations
        function obj = Ensure_Loading_Raw(obj)
            if isempty(obj.raw_image)
                obj = obj.Load_Image(); 
            end 
        end 



        %% MEMORY MANAGEMENT: 

        %% ===== Clear_Heavy_Data ===== 
        % Clear heavy matrices to free up RAM after calculations are done
        % only apply if not generating image walls. 
        function obj = Clear_Heavy_Data(obj)
            obj.raw_image = [];
            obj.uint8_image = [];
            obj.current_image = [];
            obj.stats = []; 
        end


    end % end methods 

end % end script 