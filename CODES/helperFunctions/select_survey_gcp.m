%% select_survey_gcp

% there has to be a more efficient and accurate way to do this - pull
% points from LiDAR

answer = questdlg('Do you want to select from LiDAR/SfM or image first?', 'GCP locations', 'Image', 'LiDAR/SfM', 'Image');
switch answer
    case 'Image'
        %% Choose GCP Coordinates on Image
        figure
       select_image_gcp
       gcp_num = length(h);
        %% Find corresponding points on LiDAR
        figure
        select_pointcloud_gcp
        survey_gcp = selectedPoints;
    case 'LiDAR/SfM'
        %% Get LiDAR GCPs

        answer2 = questdlg('Do you have a LiDAR/SfM template for this location? ', 'LiDAR/SfM GCP template', 'Yes', 'No', 'No');
        switch answer2
            case 'Yes'
                disp('Load in LiDAR/SfM gcp template.')
                [temp_file, temp_file_path] = uigetfile(global_dir, 'LiDAR/SfM GCP template');
                load(fullfile(temp_file_path, temp_file)); clear temp_file*

                [ind_survey_pts,tf] = listdlg('ListString', arrayfun(@num2str, [1:size(survey_gcp,1)], 'UniformOutput', false), 'SelectionMode','multiple', 'InitialValue',[1], 'PromptString', {'What survey points' 'did you use? (command + for multiple)'});
                survey_gcp = survey_gcp(ind_survey_pts,:);

                if ~exist('survey_gcp', 'var') | size(survey_gcp,2) ~= 3
                    disp('LiDAR/SfM GCPs not correct.')
                    disp('Select LiDAR/SfM GCPs.')
                    gcp_num = str2double(inputdlg({'How many LiDAR/SfM GCPs do you want to find?'}));
                    select_pointcloud_gcp
                    survey_gcp = selectedPoints;
                end
            case 'No'
                disp('Select LiDAR/SfM GCPs.')
                gcp_num = str2double(inputdlg({'How many LiDAR/SfM GCPs do you want to find?'}));
                select_pointcloud_gcp
                survey_gcp = selectedPoints;
        end

        % plot LiDAR/SfM gcps
        hLid = figure(2);clf
        ptCloudOut = pcdownsample(pc, 'random', round(100000/pc.Count,2))
       
        ax=pcshow(ptCloudOut)
        hold on
       colorbar
        caxis([0 20])
        zlim([0 20])
        xlim([min(survey_gcp(:,1))-50 max(survey_gcp(:,1))+50])
        ylim([min(survey_gcp(:,2))-50 max(survey_gcp(:,2))+50])
        hold on; % so we can highlight clicked points without clearing the figure
        scatter3(survey_gcp(:,1), survey_gcp(:,2), survey_gcp(:,3), 100, 'r', 'filled')
        for ii = 1:length(survey_gcp)
            text(survey_gcp(ii,1)+1, survey_gcp(ii,2)+1, survey_gcp(ii,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
        view(-90,90)

        %% Choose GCP Coordinates on Image
        figure
        select_image_gcp
end

        %% Allow for last minute changes to happen
        answer2 = questdlg('Are you happy with image GCP locations?', 'Image GCP locations', 'Yes', 'Yes');
        switch answer2
            case 'Yes'
                for ii = 1:length(h)
                    image_gcp(ii,:) = h(ii).Position;
                end
        end

        figure(3);clf
        subplot(122)
        imshow(I)
        hold on
        scatter(image_gcp(:,1), image_gcp(:,2), 50, 'r', 'filled')
        for ii = 1:length(image_gcp)
            text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
        subplot(121)
        scatter3(Points(:,1), Points(:,2), Points(:,3), 20, cPoints, 'filled')
        colorbar
        caxis([0 20])
        zlim([0 20])
        xlim([min(survey_gcp(:,1))-50 max(survey_gcp(:,1))+50])
        ylim([min(survey_gcp(:,2))-50 max(survey_gcp(:,2))+50])
        hold on; % so we can highlight clicked points without clearing the figure
        scatter3(survey_gcp(:,1), survey_gcp(:,2), survey_gcp(:,3)+.2, 100, 'r', 'filled')
        for ii = 1:length(survey_gcp)
            text(survey_gcp(ii,1)+1, survey_gcp(ii,2)+1, survey_gcp(ii,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
        view(-90,90)

