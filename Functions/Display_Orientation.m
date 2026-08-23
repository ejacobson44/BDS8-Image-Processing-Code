function Display_Orientation(obj, notes)

% 1. Check for data
if obj.num_segmented_objects == 0 || isempty(obj.stats)
    fprintf('Skipped Image ID %s: No objects found.\n', obj.image_ID);
    return;
end

% 2. Initialize Figure (matching your Display_Bounding_Box logic)
figure('Position', [900, 90, 600, 600]); 
imshow(obj.raw_image, [], 'InitialMagnification', 'fit');
title("Image # " + obj.image_ID + ": " + notes);
hold on

% 3. Loop through segmented objects
for i = 1:length(obj.stats)
    s = obj.stats(i);

    % Pull required regionprops
    centroid = s.Centroid;
    orientation = s.Orientation;
    a = s.MajorAxisLength/2;
    b = s.MinorAxisLength/2;
    bbox = s.BoundingBox;

    % Calculate angle in radians (negated for image coordinate system)
    theta = -deg2rad(orientation);

    % --- DRAW ELLIPSE ---
    t = linspace(0, 2*pi, 100);
    ex = centroid(1) + a*cos(t)*cos(theta) - b*sin(t)*sin(theta);
    ey = centroid(2) + a*cos(t)*sin(theta) + b*sin(t)*cos(theta);
    plot(ex, ey, 'r', 'LineWidth', 1); 

    % --- DRAW AXES ---
    % Major Axis
    x1 = centroid(1) + a * cos(theta);
    y1 = centroid(2) + a * sin(theta);
    x2 = centroid(1) - a * cos(theta);
    y2 = centroid(2) - a * sin(theta);
    line([x1, x2], [y1, y2], 'Color', 'b', 'LineWidth', 1);

    % Minor Axis
    x3 = centroid(1) + b * cos(theta + pi/2);
    y3 = centroid(2) + b * sin(theta + pi/2);
    x4 = centroid(1) - b * cos(theta + pi/2);
    y4 = centroid(2) - b * sin(theta + pi/2);
    line([x3, x4], [y3, y4], 'Color', 'b', 'LineWidth', 1, 'LineStyle', ':');

    % --- DRAW TEXT OVERLAY ---
    % Displays the orientation angle next to the bounding box
    text(bbox(1) + bbox(3) + 2, centroid(2), string(round(orientation,1)) + "°", ...
        'Color', 'blue', 'FontSize', 8, 'FontWeight', 'bold');
end

% 4. Display Scalebar (matching your specific placement/math)
% d = 100 - 10/0.6; based on your logic: 10um = 16.6 pixels
d_start = 100 - (10/0.6); 
y_pos = 35; 
k_step = 4;

plot([d_start, 100], [y_pos-k_step, y_pos-k_step], 'r-', 'LineWidth', 3);
text(d_start+2.4, y_pos, "10 µm", 'Color', "red", 'FontSize', 12)

hold off
end
