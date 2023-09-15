%% get_local_lidar
% Pulls in local lidar or SfM survey (can be Airborne or Mobile)
disp('Find local LiDAR/SfM survey folder.')
disp('For CPG: CPG_data/LiDAR/20230220_NAD83_UTM11N_NAVD88_TorreyLot.las')
[temp_file, temp_file_path] = uigetfile({'*.las'}, 'LiDAR survey location');
lasReader=lasFileReader(fullfile(temp_file_path, temp_file)); clear temp_file*
pc = readPointCloud(lasReader);
