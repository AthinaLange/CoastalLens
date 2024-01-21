function [survey_gcp, image_gcp] = select_survey_gcp(pc, I, varargin)
%
%   Choose GCP Locations in LiDAR/SfM survey and image
%
%% Syntax
%           [survey_gcp, image_gcp] = select_survey_gcp(pc, I)
%           [survey_gcp, image_gcp] = select_survey_gcp(pc, I, intrinsics_CIRN = intrinsics, extrinsicsInitialGuess = extrinsics)
%% Description
%   Args:
%           pc (PointCloud) : PointCloud to pull gcp points from
%           I (uint8) : Image to select gcp points in
%           varargin :
%                       intrinsics_CIRN : [1 x 11 array] intrinsics array as defined by CIRN 
%                       extrinsicsInitialGuess : [1 x 6 array] extrinsics array as defined by CIRN
%
%   Returns:
%          survey_gcp (array) : [3 x n] gcp coordinates for n points in pointcloud coordinate system
%          image_gcp (array) : [2 x n] gcp coordinates for n points in image
%
%   varargin's crops the Pointcloud to avoid slowing your computer
%  If Image first: click as many GCP as you want. In pointCloud, will find the same amount
%  If LiDAR/SfM first: set number of GCPs you want to find.
%
%
%% Example 1
%
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; Last revision: XXX

%%
options.intrinsics_CIRN = []; % file extension to search for
options.extrinsicsInitialGuess = [];
options = parseOptions(options , varargin);

%%

answer = questdlg('Do you want to select from LiDAR/SfM or image first?', 'GCP locations', 'Image', 'LiDAR/SfM', 'Image');
switch answer
    case 'Image'
        %% Choose GCP Coordinates on Image
        figure


        [image_gcp] = select_image_gcp(I);
        gcp_num = length(image_gcp);
        %% Find corresponding points on LiDAR
        figure
        if isempty(options.intrinsics_CIRN) || isempty(options.extrinsicsInitialGuess)
            [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num, options.intrinsics_CIRN, options.extrinsicsInitialGuess);
        else
            [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num);
        end
    case 'LiDAR/SfM'
        %% Get LiDAR GCPs

        answer2 = questdlg('Do you have a LiDAR/SfM template for this location? ', 'LiDAR/SfM GCP template', 'Yes', 'No', 'No');
        switch answer2
            case 'Yes'
                disp('Load in LiDAR/SfM gcp template.')
                [temp_file, temp_file_path] = uigetfile(pwd, 'LiDAR/SfM GCP template');
                load(fullfile(temp_file_path, temp_file)); clear temp_file*

                [ind_survey_pts,~] = listdlg('ListString', arrayfun(@num2str, [1:size(survey_gcp,1)], 'UniformOutput', false), 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'What survey points' 'did you use? (command + for multiple)'});
                survey_gcp = survey_gcp(ind_survey_pts,:);

                if ~exist('survey_gcp', 'var') | size(survey_gcp,2) ~= 3
                    disp('LiDAR/SfM GCPs not correct.')
                    disp('Select LiDAR/SfM GCPs.')
                    gcp_num = str2double(inputdlg({'How many LiDAR/SfM GCPs do you want to find?'}));
                    if isempty(options.intrinsics_CIRN) || isempty(options.extrinsicsInitialGuess)
                        [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num, options.intrinsics_CIRN, options.extrinsicsInitialGuess);
                    else
                        [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num);
                    end
                end
            case 'No'
                disp('Select LiDAR/SfM GCPs.')
                gcp_num = str2double(inputdlg({'How many LiDAR/SfM GCPs do you want to find?'}));
                if isempty(options.intrinsics_CIRN) || isempty(options.extrinsicsInitialGuess)
                    [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num, options.intrinsics_CIRN, options.extrinsicsInitialGuess);
                else
                    [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num);
                end
        end

        % plot LiDAR/SfM gcps
        hLid = figure(2);clf
        ptCloudOut = pcdownsample(pc, 'random', round(100000/pc.Count,2));

        ax=pcshow(ptCloudOut);
        hold on
        colorbar
        clim([0 20])
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

        [image_gcp] = select_image_gcp(I);
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

Points = pc.Location;
scatter3(Points(:,1), Points(:,2), Points(:,3), 20, 'filled')
colorbar
clim([0 20])
zlim([0 20])
xlim([min(survey_gcp(:,1))-50 max(survey_gcp(:,1))+50])
ylim([min(survey_gcp(:,2))-50 max(survey_gcp(:,2))+50])
hold on; % so we can highlight clicked points without clearing the figure
scatter3(survey_gcp(:,1), survey_gcp(:,2), survey_gcp(:,3)+.2, 100, 'r', 'filled')
for ii = 1:length(survey_gcp)
    text(survey_gcp(ii,1)+1, survey_gcp(ii,2)+1, survey_gcp(ii,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
end
view(-90,90)
end
