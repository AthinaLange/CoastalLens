function [survey_gcp] = select_pointcloud_gcp(pc, gcp_num, varargin)
%   Choose GCP Locations in LiDAR/SfM survey
%
%% Syntax
%          [survey_gcp] = select_pointcloud_gcp(pc, I, gcp_num, varargin)
%          [survey_gcp] = select_pointcloud_gcp(pc, I, 4, intrinsics_CIRN = intrinsics, extrinsicsInitialGuess = extrinsics)
%
%% Description
%   Args:
%           pc (PointCloud) : PointCloud to pull gcp points from
%           I (uint8) : Image to select gcp points in
%           gcp_num (double) : number of gcp's to select in pointcloud
%           varargin :
%                       intrinsics_CIRN : [1 x 11 array] intrinsics array as defined by CIRN 
%                       extrinsicsInitialGuess : [1 x 6 array] extrinsics array as defined by CIRN
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
options.Image =[];
options.intrinsics_CIRN = []; 
options.extrinsicsInitialGuess = [];
options = parseOptions(options , varargin);

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
% if ~isempty(options.intrinsics_CIRN) && ~isempty(options.extrinsicsInitialGuess)
%     disp('hi')
%     [m,n,~] = size(options.Image); % image dimensions for edge coordinates
%     i_bounds = [0 .1*m; n .1*m; n m; 0 m];
% 
%     [w_bounds] = distUV2XYZ(options.intrinsics_CIRN, options.extrinsicsInitialGuess, i_bounds', 'z', zeros(1, size(i_bounds,1)));
%     w_bounds([1 4],2) = w_bounds([1 4],2) -100;
%     w_bounds([2 3],2) = w_bounds([2 3],2) +100;
%     w_bounds([3 4],1) = w_bounds([3 4],1) +100;
%     % %
%     [in,~] = inpolygon(Points(:,1), Points(:,2),[w_bounds(1:4,1); w_bounds(1,1)], [w_bounds(1:4,2); w_bounds(1,2)]);
% 
%     if ~isempty(find(in == 1))
%         pc_new = select(pc, in);
%     else
%         pc_new = pc;
%     end
% else
%     pc_new = pc;
% end
%% Select points from pointcloud

ptCloudOut = pcdownsample(pc, 'random', round(100000/pc.Count,2));
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
    indices = findPointsInROI(pc,roi);

    pc_small = select(pc, indices);

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