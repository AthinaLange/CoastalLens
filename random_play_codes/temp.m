
ptCloudOut = pcdownsample(pc_new,'random',.1)
f=figure(1);clf
ax=pcshow(ptCloudOut)

h = images.roi.Cuboid(ax);
selectedPoints=[];
for ii = 1:gcp_num
    c = uicontrol('String','Continue','Callback','uiresume(f)');
    draw(h)
    uiwait(f)

    roi = [h.Position(1) h.Position(1)+h.Position(4) ...
        h.Position(2) h.Position(2)+h.Position(5) ...
        -5 25];
    indices = findPointsInROI(pc_new,roi);

    pc_small = select(pc_new, indices);

    [selectedPoint,f2] = select_pcshow_point(pc_small);

    scatter3(selectedPoint(1), selectedPoint(2), selectedPoint(3), 100, 'r', 'filled')
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


%%
function [selectedPoint,f2] = select_pcshow_point(pc)
    Points = pc.Location;
    f2=figure(2);clf
    pcshow(pc)
    hold on
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
    
    selectedPoint = Points(pointCloudIndex,:)'
    fprintf('you clicked on point number %d\n', pointCloudIndex);

end
