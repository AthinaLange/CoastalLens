% select_pointcloud_gcp
% click on points in a pointcloud
        % Find gcp points on LiDAR
fLid = figure(2);clf;
Points = pc.Location;
if ~isempty(pc.Color)
    cPoints = pc.Color;
else
    cPoints = Points(:,3);
end
scatter3(Points(:,1), Points(:,2), Points(:,3), 20, cPoints, 'filled')
%set(gca,'YDir', 'reverse')
colorbar
caxis([0 20])
zlim([0 20])
hold on; % so we can highlight clicked points without clearing the figure

for ii = 1: gcp_num
    sprintf('Find GCP %i.', ii)
    pause
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
        selectedPoints(ii,:)=selectedPoint;
        scatter3(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3)+.2, 100, 'r', 'filled')
        text(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14)
end

