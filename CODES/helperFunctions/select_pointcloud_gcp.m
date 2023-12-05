%% select_pointcloud_gcp
% 
% use get_noaa_lidar or get_local_survey to get pointCloud
% cut pointcloud to approximate dimensions of image
% downsample points and plot pointCloud. Move box over relevant area for a given GCP
% In zoomed in pointCloud, click on GCP, and hit Enter. Confirm if you like
% the point, or reclick.
% Repeat for all GCPs to be found
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023
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
I = imread(fullfile(odir, 'Processed_data', 'undistortImage.png'));
load(fullfile(odir, 'Processed_data', [oname '_IO']), 'intrinsics_CIRN', 'extrinsicsInitialGuess')
    
[m,n,c] = size(I); % image dimensions for edge coordinates
i_bounds = [0 .1*m; n .1*m; n m; 0 m];

[w_bounds] = distUV2XYZ(intrinsics_CIRN, extrinsicsInitialGuess, i_bounds', 'z', zeros(1, size(i_bounds,1)));
w_bounds([1 4],2) = w_bounds([1 4],2) -100;
w_bounds([2 3],2) = w_bounds([2 3],2) +100;
w_bounds([3 4],1) = w_bounds([3 4],1) +100;
% % 
[in,on] = inpolygon(Points(:,1), Points(:,2),[w_bounds(1:4,1); w_bounds(1,1)], [w_bounds(1:4,2); w_bounds(1,2)]);


pc_new = select(pc, in);
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

figure(2);clf
ax=pcshow(ptCloudOut);
hold on
scatter3(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3), 100, 'r', 'filled')



answer = questdlg('Do you want to save these survey points for future use?','Save points as template', 'Yes', 'No', 'Yes');
switch answer
    case 'Yes'
        save_dir = uigetdir('.', 'Saving location for survey points');
        disp('Find location to save survey points as template.')
        survey_save_name = string(inputdlg({'Save name for survey points.'}));
        survey_gcp = selectedPoints;
        save(fullfile(save_dir, survey_save_name), 'survey_gcp')
end % switch answer
        

%%
function [selectedPoint,zoom_fig] = select_pcshow_point(pc)
    Points = pc.Location;
    zoom_fig=figure(3);clf
    pcshow(pc)
    hold on
    pause

    disp('Zoom in and click on GCP point and press ''Enter''.')
    
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
