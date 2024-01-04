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

        disp('Load in target GCP coordinates file.')
        disp('For CPG: Should be under the individual day. gps_northings.txt')
         [temp_file, temp_file_path] = uigetfile({'*.txt'}, 'GCP Targets');
         gps_northings=load(fullfile(temp_file_path, temp_file)); clear temp_file_path
         % assuming that gps_northings in world coordinates and not in local grid system

        [ind_gcp,~] = listdlg('ListString', arrayfun(@num2str, [1:size(gps_northings,1)], 'UniformOutput', false), 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'What ground control points' 'did you use? (command + for multiple)'});
        target_gcp = gps_northings(ind_gcp, 2:4);

       
      
