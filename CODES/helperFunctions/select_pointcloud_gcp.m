function [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num, varargin)
%% select_pointcloud_gcp
%
% use get_noaa_lidar or get_local_survey to get pointCloud
% cut pointcloud to approximate dimensions of image
% downsample points and plot pointCloud. Move box over relevant area for a given GCP
% In zoomed in pointCloud, click on GCP, and hit Enter. Confirm if you like
% the point, or reclick.
% Repeat for all GCPs to be found
%
% include intrinsics_CIRN and extrinsicsInitialGuess if you want to crop pointcloud
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023
%%
if length(nargin) ~= 0
    intrinsics_CIRN = varargin{1};
    extrinsicsInitialGuess = varargin{2};
end
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
%% Cut pointcloud to approximate projection of image
if length(nargin) ~= 0
    [m,n,~] = size(I); % image dimensions for edge coordinates
    i_bounds = [0 .1*m; n .1*m; n m; 0 m];

    [w_bounds] = distUV2XYZ(intrinsics_CIRN, extrinsicsInitialGuess, i_bounds', 'z', zeros(1, size(i_bounds,1)));
    w_bounds([1 4],2) = w_bounds([1 4],2) -100;
    w_bounds([2 3],2) = w_bounds([2 3],2) +100;
    w_bounds([3 4],1) = w_bounds([3 4],1) +100;
    % %
    [in,~] = inpolygon(Points(:,1), Points(:,2),[w_bounds(1:4,1); w_bounds(1,1)], [w_bounds(1:4,2); w_bounds(1,2)]);

    pc_new = select(pc, in);
else
    pc_new = pc;
end
%% Select points from pointcloud

ptCloudOut = pcdownsample(pc_new, 'random', round(100000/pc_new.Count,2));
main_fig=figure(2);clf
ax=pcshow(ptCloudOut);

h = images.roi.Cuboid(ax);
selectedPoints=[];
for ii = 1:gcp_num
    figure(2)
    c = uicontrol('String','Continue','Callback','uiresume(main_fig)');
    draw(h)
    disp('Place cuboid over area of GCP and click ''Continue''.')
    uiwait(main_fig)

    roi = [h.Position(1) h.Position(1)+h.Position(4) ...
        h.Position(2) h.Position(2)+h.Position(5) ...
        -5 25];
    indices = findPointsInROI(pc_new,roi);

    pc_small = select(pc_new, indices);

    answer = 'Reselect';
    while contains(answer , 'Reselect')
        [selectedPoint, zoom_fig] = select_pcshow_point(pc_small);

        scatter3(selectedPoint(1), selectedPoint(2), selectedPoint(3), 100, 'r', 'filled')
        disp('Check if GCP is in the correct position. After rotating click ''See GCP?''.')
        c2 = uicontrol('String','See GCP?','Callback','uiresume(zoom_fig)');
        uiwait(zoom_fig)
        answer = questdlg('Are you happy with the point or do you want to reselect?','Happy with point', 'Yes', 'Reselect', 'Yes');
    end % while contains(answer , 'Reselect')
    selectedPoints(size(selectedPoints,1)+1,:)=selectedPoint;
    uiresume(main_fig)
end
%%
figure(2);clf
ax=pcshow(ptCloudOut);
hold on
scatter3(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3), 100, 'r', 'filled')

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