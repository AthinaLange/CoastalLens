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
