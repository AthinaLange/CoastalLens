%% get_local_sfm
% Pulls in local SfM survey
disp('Find local SfM survey folder.')
disp('For CPG: CPG_data/20220817_00581_00590_0000_NoWaves_TorreyCobble_P4RTK_epoch2010_geoid12b_cliff_ground.las')
[temp_file, temp_file_path] = uigetfile({'*.las'}, 'SfM survey location');
lasReader=lasFileReader(fullfile(temp_file_path, temp_file)); clear temp_file*
pc = readPointCloud(lasReader);
