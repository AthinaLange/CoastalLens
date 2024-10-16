function [survey_gcp] = select_pointcloud_gcp(pc, gcp_num, main_fig, zoom_fig)
%   select_pointcloud_gcp returns world coordinates (from pointcloud) of
%   selected points.
%% Syntax
%         [survey_gcp] = select_pointcloud_gcp(pc, gcp_num, main_fig, zoom_fig)
%
%% Description
%   Args:
%           pc (PointCloud) : PointCloud to pull gcp points from
%           gcp_num (double) : number of gcp's to select in pointcloud
%           main_fig (figure handle) : figure handle where pointcloud willbe displayed and zoom area chosen
%           zoom_fig (figure handle) : figure handle where zoomed in pointcloud will be displayed and point clicked
%
%   Returns:
%          survey_gcp (array) : [3 x n] gcp coordinates for n points in pointcloud coordinate system
%
%
% Place rectangle box over the relevant region for a given GCP to downsample points.
% In zoomed in pointCloud, click on GCP, and hit Enter. Confirm if you like the point, or reclick.
% Repeat for all GCPs to be found
%
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Nov 2023; 

%% Data
assert(isa(pc, 'pointCloud'), 'Error (select_pointcloud_gcp): pc must be a pointCloud object.')
assert(isa(gcp_num, 'double'), 'Error (select_pointcloud_gcp): gcp_num must be a double.')
assert(length(gcp_num) == 1, 'Error (select_pointcloud_gcp): gcp_num must be a single value.')
assert(strcmp(class(main_fig), 'matlab.ui.Figure'), 'Error (select_pointcloud_gcp): main_fig must be a figure handle.')
assert(strcmp(class(zoom_fig), 'matlab.ui.Figure'), 'Error (select_pointcloud_gcp): zoom_fig must be a figure handle.')

%% Select GCP points from pointcloud
ptCloudOut = pcdownsample(pc, 'random', 50000/pc.Count); % downsample to avoid computer crashing

ax2 = axes('Parent', main_fig);
ax3 = axes('Parent', zoom_fig);
pcshow(ptCloudOut, 'Parent', ax2);

h = images.roi.Cuboid(ax2);
selectedPoints=[];
for ii = 1:gcp_num % repeat for all gcps
    % find smaller region for specific gcp
    figure(main_fig)
    zoom on
    uicontrol('String','Continue','Callback','uiresume(main_fig)');
    draw(h)
    disp('Place cuboid over area of GCP and click ''Continue''.')
    uiwait(main_fig)

    roi = [h.Position(1) h.Position(1)+h.Position(4) ...
        h.Position(2) h.Position(2)+h.Position(5) ...
        -5 25];
    indices = findPointsInROI(pc,roi);

    pc_small = select(pc, indices);

    % select gcp point in zoomed in region
    answer = 'Reselect';
    while contains(answer , 'Reselect')
        figure(zoom_fig)
        [selectedPoint, ~] = select_pcshow_point(pc_small, zoom_fig);
        clf;ax3 = axes('Parent', zoom_fig);
        pcshow(pc_small, 'Parent', ax3);hold on
        scatter3(selectedPoint(1), selectedPoint(2), selectedPoint(3), 100, 'r', 'filled', 'Parent', ax3)
        set(ax3, 'Xlim', [selectedPoint(1)-25 selectedPoint(1)+25], 'Ylim', [selectedPoint(2)-25 selectedPoint(2)+25])
        disp('Check if GCP is in the correct position. After rotating click ''See GCP?''.')
        uicontrol('String','See GCP?','Callback','uiresume(zoom_fig)');
        uiwait(zoom_fig)
        answer = questdlg('Are you happy with the point or do you want to reselect?','Happy with point', 'Yes', 'Reselect', 'Yes');
    end % while contains(answer , 'Reselect')
    selectedPoints(size(selectedPoints,1)+1,:)=selectedPoint;
    clf(zoom_fig)
    uiresume(main_fig)
end % for ii = 1:gcp_num
%close(main_fig)
close(zoom_fig)
%%
main_fig;
pcshow(ptCloudOut, 'Parent', ax2);
hold on
scatter3(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3), 100, 'r', 'filled', 'Parent', ax2)

survey_gcp = selectedPoints;

answer = questdlg('Do you want to save these survey points for future use?','Save points as template', 'Yes', 'No', 'Yes');
switch answer
    case 'Yes'
        save_dir = uigetdir('.', 'Saving location for survey points');
        disp('Find location to save survey points as template.')
        survey_save_name = string(inputdlg({'Save name for survey points.'}));
        save(fullfile(save_dir, survey_save_name), 'survey_gcp')
end % switch answer


end