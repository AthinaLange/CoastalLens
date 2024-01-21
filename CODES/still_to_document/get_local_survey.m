function [pc] = get_local_survey
%   Load in user-selected pointcloud.
%
%   Examples:
%           [pc] = get_local_survey
%
%   Args:
%           
%
%   Returns:
%           pc (pointcloud) : Pointcloud loaded in
%               
% 
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%% get_local_survey
% Pulls in local lidar or SfM survey (can be Airborne or Mobile)
% Find .las file
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023
%%
disp('Find local LiDAR/SfM survey folder.')
disp('For CPG LiDAR: CPG_data/LiDAR/20230220_NAD83_UTM11N_NAVD88_TorreyLot.las')
disp('For CPG SfM: CPG_data/20220817_00581_00590_NoWaves_TorreyCobble_P4RTK_epoch2010_geoid12b.las')
[temp_file, temp_file_path] = uigetfile({'*.las'}, 'Survey location');
lasReader=lasFileReader(fullfile(temp_file_path, temp_file)); clear temp_file*
pc = readPointCloud(lasReader);
end