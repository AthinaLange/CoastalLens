%% get_local_lidar
% Pulls in local lidar survey (can be Airborne or Mobile)
disp('Find local LiDAR survey folder.')
disp('For CPG: CPG_data/LiDAR/20230220_NAD83_UTM11N_NAVD88_TorreyLot.las')
[temp_file, temp_file_path] = uigetfile({'*.las'}, 'LiDAR survey location');
lasReader=lasFileReader(fullfile(temp_file_path, temp_file)); clear temp_file*
lidarData = readPointCloud(lasReader);

 [y2,x2, ~] = ll_to_utm(origin_grid(1), origin_grid(2));

% Transform LiDAR UTM coordinates into grid
lidarPoints = lidarData.Location;
%% TO DO - adjust for east or west coast
lidarPoints(:, 1) = x2 - lidarPoints(:,1);
lidarPoints(:, 2) = -(y2 - lidarPoints(:,2));
