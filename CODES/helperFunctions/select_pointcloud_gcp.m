function [survey_gcp] = select_pointcloud_gcp(pc, gcp_num, main_fig, zoom_fig)
%   Choose GCP Locations in LiDAR/SfM survey
%
%% Syntax
%          [survey_gcp] = select_pointcloud_gcp(pc, gcp_num)
%
%% Description
%   Args:
%           pc (PointCloud) : PointCloud to pull gcp points from
%           gcp_num (double) : number of gcp's to select in pointcloud
%
%   Returns:
%          survey_gcp (array) : [3 x n] gcp coordinates for n points in pointcloud coordinate system
%
%  varargin's crops the Pointcloud to avoid slowing your computer
%  cut pointcloud to approximate dimensions of image
%  downsample points and plot pointCloud. Move box over relevant area for a given GCP
%  In zoomed in pointCloud, click on GCP, and hit Enter. Confirm if you like the point, or reclick.
%  Repeat for all GCPs to be found
%
%
%
%% Example 1
%
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; Last revision: XXX


%%
Points = pc.Location;
if ~isempty(pc.Color)
    cPoints = pc.Color;
    if contains(class(cPoints), 'uint16')
        cPoints = double(cPoints) / 65535;
    end
else
    cPoints = Points(:,3);
end

%% Select points from pointcloud

ptCloudOut = pcdownsample(pc, 'random', 50000/pc.Count);

ax2 = axes('Parent', main_fig);
ax3 = axes('Parent', zoom_fig);
pcshow(ptCloudOut, 'Parent', ax2);

h = images.roi.Cuboid(ax2);
selectedPoints=[];
for ii = 1:gcp_num
    figure(main_fig)
    zoom on
    c = uicontrol('String','Continue','Callback','uiresume(main_fig)');
    draw(h)
    disp('Place cuboid over area of GCP and click ''Continue''.')
    uiwait(main_fig)

    roi = [h.Position(1) h.Position(1)+h.Position(4) ...
        h.Position(2) h.Position(2)+h.Position(5) ...
        -5 25];
    indices = findPointsInROI(pc,roi);

    pc_small = select(pc, indices);

    answer = 'Reselect';
    while contains(answer , 'Reselect')
        figure(zoom_fig)
        [selectedPoint, zoom_fig] = select_pcshow_point(pc_small, zoom_fig);
        pcshow(pc_small);hold on
        scatter3(selectedPoint(1), selectedPoint(2), selectedPoint(3), 100, 'r', 'filled')
        set(gca, 'Xlim', [selectedPoint(1)-25 selectedPoint(1)+25], 'Ylim', [selectedPoint(2)-25 selectedPoint(2)+25])
        disp('Check if GCP is in the correct position. After rotating click ''See GCP?''.')
        c2 = uicontrol('String','See GCP?','Callback','uiresume(zoom_fig)');
        uiwait(zoom_fig)
        answer = questdlg('Are you happy with the point or do you want to reselect?','Happy with point', 'Yes', 'Reselect', 'Yes');
    end % while contains(answer , 'Reselect')
    selectedPoints(size(selectedPoints,1)+1,:)=selectedPoint;
    clf(zoom_fig)
    uiresume(main_fig)
end
%close(main_fig)
close(zoom_fig)
%%
main_fig
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


%%
end