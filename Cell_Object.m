


classdef Cell_Object
    properties 
        % constructor properties
        parent_image_ID
        stat_index_number
        stats
        % 'Area', 'BoundingBox', 'EquivDiameter','MeanIntensity', 'PixelValues', 
        %  'Image' 
        cutout_uint8
        cutout_mask
        

        % calculations 
        internal_CV
        GUVness 
        


    end 


    methods 
        % constructor methods 
        function obj = Cell_Object(parent_image_ID, stats, stat_index_number, cutout_raw, cutout_mask)

            obj.parent_image_ID = parent_image_ID;  
            obj.stats = stats; 
            obj.stat_index_number = stat_index_number;  
            obj.cutout_uint8 = cutout_raw; 
            obj.cutout_mask = cutout_mask;


            obj = obj.Recalculate_Centroid();
        end
        
        % Automatically recalculate local coordinates using the cutout mask
        % Automatically recalculate local coordinates using the cutout mask
        function obj = Recalculate_Centroid(obj)
            if ~isempty(obj.cutout_mask)
                % Measure the cell shape and internal pixels in its new localized frame
                local_props = regionprops(obj.cutout_mask, obj.cutout_uint8, ...
                    'Centroid', 'WeightedCentroid', 'PixelList', 'PixelValues', 'MeanIntensity');
                
                % Update tracking coordinates and values to the local cutout window frame
                obj.stats.Centroid = local_props(1).Centroid;
                obj.stats.WeightedCentroid = local_props(1).WeightedCentroid;
                obj.stats.PixelList = local_props(1).PixelList;
                obj.stats.PixelValues = local_props(1).PixelValues;
                obj.stats.MeanIntensity = local_props(1).MeanIntensity; 
            end
        end


        function obj = Calculate_GUVness(obj)
            if ~isempty(obj.stats) && isfield(obj.stats, 'PixelValues') && isfield(obj.stats, 'PixelList')
                pixel_intensities = obj.stats.PixelValues;

                if ~isempty(pixel_intensities)
                    % 1. Find the absolute maximum brightness value
                    max_val = max(pixel_intensities);

                    % 2. Find the indices of ALL pixels that share this max brightness
                    max_indices = find(pixel_intensities == max_val);

                    % 3. Pull local geometric Centroid coordinates
                    cX = obj.stats.Centroid(1);
                    cY = obj.stats.Centroid(2);

                    % 4. Handle ties if multiple pixels share peak brightness
                    if length(max_indices) > 1
                        % Extract the [X,Y] coordinates for all peak brightness candidates
                        candidate_XY = obj.stats.PixelList(max_indices, :);

                        % Calculate the Euclidean distance for each candidate from the centroid
                        distances = sqrt((candidate_XY(:,1) - cX).^2 + (candidate_XY(:,2) - cY).^2);

                        % Find the index of the candidate that is furthest away
                        [~, furthest_candidate_idx] = max(distances);

                        % Map back to the original pixel list index
                        final_max_idx = max_indices(furthest_candidate_idx);
                    else
                        % Only one pixel has the max value, no tie-breaker needed
                        final_max_idx = max_indices(1);
                    end

                    % 5. Extract the coordinates of the chosen furthest peak pixel
                    brightest_XY = obj.stats.PixelList(final_max_idx, :);
                    brightest_X = brightest_XY(1);
                    brightest_Y = brightest_XY(2);

                    % 6. Compute normalized Euclidean distance and assign it to the object
                    obj.GUVness = sqrt((brightest_X - cX)^2 + (brightest_Y - cY)^2) / (0.5 * obj.stats.MinorAxisLength);
                else
                    obj.GUVness = [];
                end
            else
                obj.GUVness = [];
            end
        end




        function obj = Calculate_CV(obj)
            if ~isempty(obj.stats) && isfield(obj.stats, 'PixelValues')
                pixels = double(obj.stats.PixelValues); % Pulls 8 bit values
                
                local_mean = mean(pixels);
                if local_mean > 0
                    obj.internal_CV = std(pixels) / local_mean;
                else
                    obj.internal_CV = 0;
                end
            end
        end
        


        function obj = Clear_Heavy_Data(obj)
            obj.cutout_uint8 = [];
            obj.cutout_mask = []; 
            %obj.stats = []; 
        end

        
      


    end 


end 
    