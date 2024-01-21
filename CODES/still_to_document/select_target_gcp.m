function [target_gcp] = select_target_gcp
%% select_target_gcp
% add check that gps_northings in correct format
%
% Select corresponding coordinates for the targets that were chosen in select_image_gcp
% Assumes target coordinates in world coordinates (UTM)
%
% Requires: must be run after select_image_gcp
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%% Get target world coordinates from file

% assuming that gps_northings in world coordinates and not in local grid system
disp('Load in target GCP coordinates file.')
disp('For CPG: Should be under the individual day. gps_northings.txt')
[target_gcp] = select_data_from_text_file;
target_gcp = target_gcp(:, 2:4);

end