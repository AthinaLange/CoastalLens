function [pc] = load_pointcloud
%   Load in user-selected pointcloud (from .las file).
%% Syntax
%           [pc] = load_pointcloud
%
%% Description
%   Args:     
%
%   Returns:
%           pc (pointcloud) : User-selected pointcloud
% 
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; 
%%
[temp_file, temp_file_path] = uigetfile({'*.las'}, 'Pointcloud location');
lasReader=lasFileReader(fullfile(temp_file_path, temp_file)); clear temp_file*
pc = readPointCloud(lasReader);
end