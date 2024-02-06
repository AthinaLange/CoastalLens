function [survey_gcp, image_gcp] = select_survey_gcp(I, image_fig, main_fig, zoom_fig)
%   select_survey_gcp returns world coordinates (from pointcloud) and pixel coordinates of selected points in image.
%% Syntax
%           [survey_gcp, image_gcp] = select_survey_gcp(I, image_fig,main_fig, zoom_fig)
%% Description
%   Args:
%           I (uint8) : Image to select gcp points in
%           image_fig (figure handle) : figure handle for image to load in
%           main_fig (figure handle) : figure handle where pointcloud willbe displayed and zoom area chosen
%           zoom_fig (figure handle) : figure handle where zoomed in pointcloud will be displayed and point clicked
%
%   Returns:
%          survey_gcp (double) : [3 x n] gcp coordinates for n points in pointcloud coordinate system
%          image_gcp (double) : [2 x n] gcp coordinates for n points in image
%
%  If Image first: click as many GCP as you want. In pointCloud, will find the same amount
%  If LiDAR/SfM first: set number of GCPs you want to find.
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Data
assert(isa(I, 'uint8'), 'Error (select_survey_gcp): I must be a uint8 image.')
assert(strcmp(class(image_fig), 'matlab.ui.Figure'), 'Error (select_survey_gcp): image_fig must be a figure handle.')
assert(strcmp(class(main_fig), 'matlab.ui.Figure'), 'Error (select_survey_gcp): main_fig must be a figure handle.')
assert(strcmp(class(zoom_fig), 'matlab.ui.Figure'), 'Error (select_survey_gcp): zoom_fig must be a figure handle.')

%%
% Do you already have a template.
answer2 = questdlg('Do you have a LiDAR/SfM template for this location? ', 'LiDAR/SfM GCP template', 'Yes', 'No', 'No');
switch answer2
    case 'Yes'
        disp('Load in LiDAR/SfM gcp template.')
        [temp_file, temp_file_path] = uigetfile(pwd, 'LiDAR/SfM GCP template');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*

        [ind_survey_pts,~] = listdlg('ListString', arrayfun(@num2str, [1:size(survey_gcp,1)], 'UniformOutput', false), 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'What survey points' 'did you use? (command + for multiple)', ''}, 'ListSize', [500 300]);
        aa = survey_gcp(ind_survey_pts,:); clear survey_gcp;
        survey_gcp = aa;
end % switch answer2

if ~exist('survey_gcp', 'var') || size(survey_gcp,2) ~= 3
    disp('Find local LiDAR/SfM survey folder.')
    disp('For CPG LiDAR: CPG_data/LiDAR/20230220_NAD83_UTM11N_NAVD88_TorreyLot.las')
    disp('For CPG SfM: CPG_data/20220817_00581_00590_NoWaves_TorreyCobble_P4RTK_epoch2010_geoid12b.las')

    [pc] = load_pointcloud;
    answer = questdlg('Do you want to select from LiDAR/SfM or image first?', 'GCP locations', 'Image', 'LiDAR/SfM', 'Image');
    switch answer
        case 'Image'
            %% Choose GCP Coordinates on Image
            [image_gcp] = select_image_gcp(I, image_fig);
            close(image_fig)
            gcp_num = length(image_gcp);
            %% Find corresponding points on LiDAR
            [survey_gcp] = select_pointcloud_gcp(pc, gcp_num, main_fig, zoom_fig);
        case 'LiDAR/SfM'
            disp('Select LiDAR/SfM GCPs.')
            gcp_num = str2double(inputdlg({'How many LiDAR/SfM GCPs do you want to find? Minimum 4.'}));
            if gcp_num < 4
                gcp_num = 4;
            end % if gcp_num < 4
            [survey_gcp] = select_pointcloud_gcp(pc, gcp_num, main_fig, zoom_fig);

            % plot LiDAR/SfM gcps
            main_fig
            ptCloudOut = pcdownsample(pc, 'random', 50000/pc.Count);

            ax=pcshow(ptCloudOut);
            hold on
            colorbar
            clim([0 20])
            zlim([0 20])
            xlim([min(survey_gcp(:,1))-50 max(survey_gcp(:,1))+50])
            ylim([min(survey_gcp(:,2))-50 max(survey_gcp(:,2))+50])
            hold on; % so we can highlight clicked points without clearing the figure
            scatter3(survey_gcp(:,1), survey_gcp(:,2), survey_gcp(:,3), 100, 'r', 'filled')
            for ii = 1:size(survey_gcp,1)
                text(survey_gcp(ii,1)+1, survey_gcp(ii,2)+1, survey_gcp(ii,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
            end % for ii = 1:size(survey_gcp,1)
            view(-90,90)
            %% Choose GCP Coordinates on Image
            [image_gcp] = select_image_gcp(I, image_fig);
    end % switch answer
else
    %% Choose GCP Coordinates on Image
    [image_gcp] = select_image_gcp(I, image_fig);
end % if ~exist('survey_gcp', 'var') | size(survey_gcp,2) ~= 3

end