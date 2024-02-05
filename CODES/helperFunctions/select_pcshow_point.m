function [selectedPoint, zoom_fig] = select_pcshow_point(pc, zoom_fig)
%  select_pcshow_point returns world coordinates of point selected in pointcloud.
%% Syntax
%           [selectedPoint, zoom_fig] = select_pcshow_point(pc, zoom_fig)
%
%% Description
%   Args:
%           pc (pointCloud) : pointcloud where user is selecting point
%           zoom_fig (figure handle) : figure handle where pointcloud will
%           be displayed and point clicked
% 
%   Returns:
%       selectedPoints (double) : [3 x 1] (x,y,z) coordinates of selected point from pointcloud pc
%       zoom_fig (figure handle) : figure handle where pointcloud will be displayed and point clicked
%
%
%   Passing the figure handle is necessary.
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Data
assert(isa(pc, 'pointCloud'), 'Error (select_pcshow_point): pc must be a pointCloud object.')
assert(strcmp(class(zoom_fig), 'matlab.ui.Figure'), 'Error (select_pcshow_point): zoom_fig must be a figure handle.')

%% Plot pointcloud
Points = pc.Location;
clf(zoom_fig)
ax = axes('Parent',zoom_fig);
pcshow(pc, 'Parent', ax)
zoom on
hold on
pause

disp('Zoom in and click on GCP point and press ''Enter''.')

% Get clicked point coordinates
point = get(gca, 'CurrentPoint'); % mouse click position
camPos = get(gca, 'CameraPosition'); % camera position
camTgt = get(gca, 'CameraTarget'); % where the camera is pointing to

camDir = camPos - camTgt; % camera direction
camUpVect = get(gca, 'CameraUpVector'); % camera 'up' vector

% build an orthonormal frame based on the viewing direction and the
% up vector (the "view frame")
zAxis = camDir/norm(camDir);
upAxis = camUpVect/norm(camUpVect);
xAxis = cross(upAxis, zAxis);
yAxis = cross(zAxis, xAxis);

rot = [xAxis; yAxis; zAxis]; % view rotation

% the point cloud represented in the view frame
rotatedPointCloud = rot * Points';

% the clicked point represented in the view frame
rotatedPointFront = rot * point' ;

% find the nearest neighbour to the clicked point
pointCloudIndex = dsearchn(rotatedPointCloud(1:2,:)', ...
    rotatedPointFront(1:2));

selectedPoint = Points(pointCloudIndex,:)';
fprintf('you clicked on point number %d\n', pointCloudIndex);

end
