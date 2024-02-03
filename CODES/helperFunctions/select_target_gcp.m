function [target_gcp] = select_target_gcp
% Select corresponding coordinates for the targets that were chosen in select_image_gcp
%% Syntax
%           [target_gcp] = select_target_gcp
%% Description
%   Args:
%
%   Returns:
%          target_gcp (array) : [2 x n] gcp coordinates for n points pulled from text file
%
% Format of data in data file: # Eastings Northings Elevation
% Assumes target coordinates in world coordinates (UTM)
%
%   Function dependencies:
%       select_data_from_text_file
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; Last revision: XXX

%% Get target world coordinates from file

% assuming that gps_northings in world coordinates and not in local grid system
disp('Load in target GCP coordinates file.')
disp('For DEMO: Under the individual day. gps_northings.txt')
[target_gcp] = select_data_from_text_file;
target_gcp = target_gcp(:, 2:4);

end