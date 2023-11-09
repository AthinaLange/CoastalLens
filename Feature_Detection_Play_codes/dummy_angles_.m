%% dummy projection example


world_point = [0 0 0; -1 -1 0; 1 -1 0; -1 1 0; 1 1 0]';


camera_point = [0 -60*sqrt(3) 60]'; % (-11, -104, 60)
camera_angle = [-180-60 0 0]; 
R = eul2rotm(deg2rad(camera_angle), 'XYZ')

% 
% camera_point = [-11 -104 60]'; % (-11, -104, 60)
% camera_angle = [-180+60 0 -90-84]; 
% R = eul2rotm(deg2rad(camera_angle), 'XYZ');
% 

extrinsics = [R, camera_point];
P_camera_homogeneous = cameraParams_undistorted.Intrinsics.K* extrinsics *  [world_point; ones(1, size(world_point,2))];
%P_camera = P_camera_homogeneous(1:3) / P_camera_homogeneous(4)
R*P_camera + camera_point

clf
scatter3(0,0,0,50, 'filled')
hold on
plot3([-200 200],[200 200], [0 0])
plot3([-200 -200],[-200 200], [0 0])
plot3([200 200],[-200 200], [0 0])
plot3([-200 200],[-200 -200], [0 0])
plotCamera(Size=10,Orientation = R, Location = camera_point)


clf
subplot(121)
scatter3(world_point(1,:), world_point(2,:), world_point(3,:),100, colors(1:5,:), 'filled')
hold on
plot3([-200 200],[200 200], [0 0])
plot3([-200 -200],[-200 200], [0 0])
plot3([200 200],[-200 200], [0 0])
plot3([-200 200],[-200 -200], [0 0])
plotCamera(Size=10,Orientation = R, Location = camera_point)
xlabel('x ->')
ylabel('y ->')
zlabel('z ->')
set(gca, 'FontSize', 20)
%xlim([-5 5])
%ylim([-5 5])

subplot(122)
scatter(P_camera_homogeneous(1,:), P_camera_homogeneous(2,:), 100,colors(1:5,:), 'filled')
xlabel('x ->')
ylabel('<- y')
set(gca, 'YDir', 'reverse')
axis square
hold on

%%
tform = rigidtform3d(R,camera_point)
iP = world2img(world_point',tform, cameraParams_undistorted.Intrinsics )'

subplot(122)
scatter(iP(1,:), iP(2,:), 100,colors(1:5,:))
xlabel('x ->')
ylabel('<- y')
set(gca, 'YDir', 'reverse')
axis square