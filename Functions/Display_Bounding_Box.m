function Display_Bounding_Box(I, bounding_boxes, imageID, notes)
    diameters = [];

    figure('Position',[900, 90, 600, 600]);       % create a movable window
    
    % If it's already an 8-bit image, show it on the fixed [0, 255] global scale.
    % Otherwise, use your original working [] local scaling.
    if isa(I, 'uint8')
        imshow(I, [0, 255], 'InitialMagnification', 'fit'); 
    else
        imshow(I, [], 'InitialMagnification', 'fit'); % Your original working line
    end
    
    title(" Image # " + imageID + ": " + notes);
    hold on

    if ~isempty(bounding_boxes)
        for object_index = 1:length(bounding_boxes)
            bbox = bounding_boxes(object_index).BoundingBox;  % [x, y, width, height]
            rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 1.5); % display rectangle

            diameter_pixels = bbox(3)*0.6;    % width in pixels
            s = num2str(diameter_pixels); % convert number of pixels to string

            text(bbox(1)+bbox(3)/3, bbox(2)+bbox(4)/1.8, s, 'Color', 'red','FontSize', 13) % display number of pixels
            diameters(end+1) = diameter_pixels;
        end
    else
        disp("skipped")
        disp(imageID)
    end

    d = 100 - 10/0.6; % calculate scale bar placement
    y = 35; % placement
    k = 4; % step
    
    % Display scalebar
    plot([d, 100], [y-k, y-k], 'r-', 'LineWidth', 3);
    text(d+2.4, y, "10 µm", 'Color', "red",'FontSize', 13)
    hold off
end