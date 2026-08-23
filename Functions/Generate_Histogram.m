function Generate_Histogram(input_array, chart_title, x_axis_title, should_save)
    % Handle optional 4th argument (defaults to false if not passed)
    if nargin < 4
        should_save = false;
    end

    % Remove any potential NaN or empty values that could break calculations
    clean_data = input_array(~isnan(input_array) & ~isempty(input_array));

    % 1. Calculate the required statistics
    num_objects = length(clean_data);
    mean_val    = mean(clean_data);
    median_val  = median(clean_data);
    std_val     = std(clean_data);
    
    % CV is defined as Standard Deviation divided by the Mean
    if mean_val ~= 0
        cv_val  = std_val / mean_val;
    else
        cv_val  = 0; % Avoid division by zero if mean is 0
    end

    % 2. Create the plot
    fig = figure('Color', 'w');  % Assigned to variable 'fig' for exporting
    histogram(clean_data, 100, 'FaceColor', [0.4 0.6 0.9], 'EdgeColor', 'none'); 
    
    xlabel(x_axis_title);
    ylabel('Frequency');
    title(chart_title);
    grid on;

    % Set Y-axis to logarithmic scale as requested
    % set(gca, 'YScale', 'log');

    % 3. Construct the annotation text box string
    stats_str = { ...
        sprintf('N: %d', num_objects), ...
        sprintf('Mean: %.2f', mean_val), ...
        sprintf('Median: %.2f', median_val), ...
        sprintf('CV: %.3f', cv_val) ...
    };

    % 4. Display the annotation box in the upper right corner (NorthEast)
    annotation('textbox', [0.68, 0.72, 0.22, 0.18], 'String', stats_str, ...
        'FontSize', 10, 'FontName', 'Helvetica', ...
        'BackgroundColor', 'w', 'EdgeColor', [0.7 0.7 0.7], ...
        'LineWidth', 1, 'Margin', 6);

    % =========================================================================
    % 5. OPTIONAL EXPORT ENGINE
    % =========================================================================
    if should_save
        % Convert chart title to a valid, safe filename (removes spaces, slashes, etc.)
        safe_title = regexprep(chart_title, '[^a-zA-Z0-9_-]', '_');
        filename = safe_title + ".png";
        
        % Export as a razor-sharp 300 DPI image file
        exportgraphics(fig, filename, 'Resolution', 300);
        fprintf('Histogram successfully saved to disk as: %s\n', filename);
    end
end