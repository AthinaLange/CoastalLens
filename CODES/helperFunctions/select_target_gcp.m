function [target_gcp] = select_target_gcp
% select_target_gcp returns selected corresponding coordinates for the
% points that were chosen in select_image_gcp.
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
% github.com/AthinaLange/CoastalLens
% Nov 2023; 

%% Get target world coordinates from file

% assuming that GCP coordinates in world coordinates and not in local grid system
disp('Load in target GCP coordinates file.')
[target_gcp] = select_data_from_text_file;
target_gcp = target_gcp(:, 2:4);

end