function [pc] = load_pointcloud
%   Load in user-selected pointcloud (from .las file).
%
%   Examples:
%           [pc] = load_pointcloud
%
%   Args:
%           
%
%   Returns:
%           pc (pointcloud) : Loaded in pointcloud
%               
% 
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023
%%
[temp_file, temp_file_path] = uigetfile({'*.las'}, 'Pointcloud location');
lasReader=lasFileReader(fullfile(temp_file_path, temp_file)); clear temp_file*
pc = readPointCloud(lasReader);
end