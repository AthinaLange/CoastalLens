% select_pointcloud_gcp
% click on points in a pointcloud
        % Find gcp points on LiDAR
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
load(fullfile(odir, 'Processed_data', [oname '_IO']), 'intrinsics', 'extrinsicsInitialGuess')
        
[m,n,c] = size(I); % image dimensions for edge coordinates
i_bounds = [0 .1*m; n .1*m; n m; 0 m];

[w_bounds] = distUV2XYZ(intrinsics, extrinsicsInitialGuess, i_bounds', 'z', zeros(1, size(i_bounds,1)));
w_bounds([1 4],2) = w_bounds([1 4],2) -100;
w_bounds([2 3],2) = w_bounds([2 3],2) +100;
w_bounds([3 4],1) = w_bounds([3 4],1) +100;
% % 
[in,on] = inpolygon(Points(:,1), Points(:,2),[w_bounds(1:4,1); w_bounds(1,1)], [w_bounds(1:4,2); w_bounds(1,2)]);
%Points = Points(in,:);
%cPoints = cPoints(in,:);

pc_new = select(pc, in);
%% Select points from pointcloud

ptCloudOut = pcdownsample(pc_new,'random',.1);
f=figure(2);clf
ax=pcshow(ptCloudOut);

h = images.roi.Cuboid(ax);
selectedPoints=[];
for ii = 1:gcp_num
    figure(2)
    c = uicontrol('String','Continue','Callback','uiresume(f)');
    draw(h)
    disp('Place cuboid over area of GCP and click ''Continue''.')
    uiwait(f)

    roi = [h.Position(1) h.Position(1)+h.Position(4) ...
        h.Position(2) h.Position(2)+h.Position(5) ...
        -5 25];
    indices = findPointsInROI(pc_new,roi);

    pc_small = select(pc_new, indices);

    [selectedPoint,f2] = select_pcshow_point(pc_small);

    scatter3(selectedPoint(1), selectedPoint(2), selectedPoint(3), 100, 'r', 'filled')
    disp('Check if GCP is in the correct position. After rotating click ''See GCP?''.')
    c2 = uicontrol('String','See GCP?','Callback','uiresume(f2)');
    uiwait(f2)
    answer = questdlg('Are you happy with the point or do you want to reselect?','Happy with point', 'Yes', 'Reselect', 'Yes');
    switch answer
        case 'Yes'
            selectedPoints(size(selectedPoints,1)+1,:)=selectedPoint;
        case 'Reselect'
            [selectedPoint,f2] = select_pcshow_point(pc_small)
            scatter3(selectedPoint(1), selectedPoint(2), selectedPoint(3), 100, 'r', 'filled')
            selectedPoints(size(selectedPoints,1)+1,:)=selectedPoint;
    end
end

figure(2)
hold on
scatter3(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3), 100, 'r', 'filled')

%%
function [selectedPoint,f2] = select_pcshow_point(pc)
    Points = pc.Location;
    f2=figure(3);clf
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
    
    selectedPoint = Points(pointCloudIndex,:)'
    fprintf('you clicked on point number %d\n', pointCloudIndex);

end
%% Select points from pointcloud
% fLid = figure(2);clf;
% pcshow(pc_new);
% %scatter3(Points(:,1), Points(:,2), Points(:,3), 20, cPoints, 'filled')
% %set(gca,'YDir', 'reverse')
% %colorbar
% %caxis([0 20])
% %zlim([0 20])
% hold on; % so we can highlight clicked points without clearing the figure
% 
% for ii = 1: gcp_num
%     sprintf('Find GCP %i.', ii)
%     pause
%     point = get(gca, 'CurrentPoint'); % mouse click position
%         camPos = get(gca, 'CameraPosition'); % camera position
%         camTgt = get(gca, 'CameraTarget'); % where the camera is pointing to
% 
%         camDir = camPos - camTgt; % camera direction
%         camUpVect = get(gca, 'CameraUpVector'); % camera 'up' vector
% 
%         % build an orthonormal frame based on the viewing direction and the 
%         % up vector (the "view frame")
%         zAxis = camDir/norm(camDir);    
%         upAxis = camUpVect/norm(camUpVect); 
%         xAxis = cross(upAxis, zAxis);
%         yAxis = cross(zAxis, xAxis);
% 
%         rot = [xAxis; yAxis; zAxis]; % view rotation 
% 
%         % the point cloud represented in the view frame
%         rotatedPointCloud = rot * Points'; 
% 
%         % the clicked point represented in the view frame
%         rotatedPointFront = rot * point' ;
% 
%         % find the nearest neighbour to the clicked point 
%         pointCloudIndex = dsearchn(rotatedPointCloud(1:2,:)', ... 
%             rotatedPointFront(1:2));
% 
%         selectedPoint = Points(pointCloudIndex,:)';
%         fprintf('you clicked on point number %d\n', pointCloudIndex);
%         selectedPoints(ii,:)=selectedPoint;
%         scatter3(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3)+.2, 100, 'r', 'filled')
%         text(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14)
% end
% 
