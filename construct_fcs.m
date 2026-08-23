function [fcs_data, channel_names] = construct_fcs(settings)
%CONSTRUCT_FCS Parses an FCS file based on the provided settings structure.

%% --- Open fcs file --- 

fcs_root = settings.select_file;

fid = fopen(fcs_root, 'r', 'l'); 
if fid == -1, error('Cannot open file: %s.', fcs_root); end
% Read every single byte of the file as text characters.
raw_bytes = fread(fid, Inf, '*char')';
fclose(fid);

% parse metadata values
metadata_segments = splitlines(raw_bytes); 

% reconstruct fcs file
channel_names = {}; % prealocate

% Loop through the lines to hunt for structural keys and their properties.
for k = 1:length(metadata_segments)-1
    key = upper(strtrim(metadata_segments{k}));    % Current line (The Key)
    val = strtrim(metadata_segments{k+1});          % Next line (The Key's Value)
    
    % If a key matches $P[Number]N (e.g., $P1N, $P2N), its value is a channel name.
    if startsWith(key, '$P') && endsWith(key, 'N')
        channel_names{end+1} = val; 
    end
    % Capture the total cells ($TOT), data start byte ($BEGINDATA), and end byte ($ENDDATA).
    if strcmp(key, '$TOT'),       total_events = sscanf(val, '%d'); end
    if strcmp(key, '$BEGINDATA'), data_start   = sscanf(val, '%d'); end
    if strcmp(key, '$ENDDATA'),   data_end     = sscanf(val, '%d'); end
end

num_channels = length(channel_names);

% . EXTRACT NUMERIC DATA BLOCK
fid = fopen(fcs_root, 'r', 'l');
% Jump the file pointer directly to the exact byte location where numbers begin.
fseek(fid, data_start, 'bof');

% Calculate element count: Each single-precision float uses exactly 4 bytes of data.
num_elements = (data_end - data_start + 1) / 4; 
raw_matrix = fread(fid, num_elements, 'float32');
fclose(fid);


% reconstruct the matrix 

fcs_data = reshape(raw_matrix, [num_channels, total_events])';

end