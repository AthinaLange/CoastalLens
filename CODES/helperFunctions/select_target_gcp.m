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
         load(fullfile(temp_file_path, temp_file)); clear temp_file*
   
         % assuming that gps_northings in world coordinates and not in local grid system

        [ind_gcp,tf] = listdlg('ListString', arrayfun(@num2str, [1:size(gps_northings,1)], 'UniformOutput', false), 'SelectionMode','multiple', 'InitialValue',[1], 'PromptString', {'What ground control points' 'did you use? (command + for multiple)'});
        target_gcp = gps_northings(ind_gcp, 2:4);

        %% Allow for last minute changes to happen
        answer2 = questdlg('Are you happy with image GCP locations?', 'Image GCP locations', 'Yes', 'Yes');
        switch answer2
            case 'Yes'
                for ii = 1:length(h)
                    image_gcp(ii,:) = h(ii).Position;
                end
        end
        
        figure(3);clf
        imshow(I)
        hold on
        scatter(image_gcp(:,1), image_gcp(:,2), 50, 'r')
        for ii = 1:length(image_gcp)
            text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
      