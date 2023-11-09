load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/Inital_coordinates.mat', 'extrinsicsInitialGuess')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/UAV_automated_rectification/CPG_data_sample/cameraParams_whitecap.mat')

clearvars -except extrinsicsInitialGuess cameraParams_undistorted  colors
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/input_data.mat', 'origin_grid')
[y2,x2, ~] = ll_to_utm(origin_grid(1), origin_grid(2));
%%
extrinsicsInitialGuess = extrinsics;
extrinsicsInitialGuess(1) = x2 - extrinsicsInitialGuess(1);
extrinsicsInitialGuess(2) = -(y2 - extrinsicsInitialGuess(2));
extrinsicsInitialGuess(4:6) = rad2deg(extrinsicsInitialGuess(4:6))

%%
% 
% %camera_point = [-11 -60*sqrt(3) 60]'; % (-11, -104, 60)
% %camera_angle = [-180-60 0 6]; -84+90
% R = eul2rotm(deg2rad(camera_angle), 'XYZ')

% extrinsics = [R, -camera_point; 0 0 0 1];
% P_camera_homogeneous =  cameraParams_undistorted.Intrinsics.K *extrinsics * [world_point; ones(1, size(world_point,2))];
% P_camera = P_camera_homogeneous(1:3,:) ./ P_camera_homogeneous(4,:)


% camera_mat = double(cameraParams_undistorted.Intrinsics.K) * [R, camera_point]
% P_camera_homogeneous = ([world_point; ones(1, size(world_point,2))]' * camera_mat')';
% P_camera = P_camera_homogeneous(1:2,:) ./ P_camera_homogeneous(3,:)
%%
%world_point = [0 0 0; -1 -1 0; 1 -1 0; -1 1 0; 1 1 0]';
world_point = [0 0 0]'
camera_point = [extrinsicsInitialGuess(2) extrinsicsInitialGuess(1) extrinsicsInitialGuess(3)]';
camera_point=[-1 -1 1]
%camera_angle = [180-extrinsicsInitialGuess(5) 0 50]%-extrinsicsInitialGuess(4)];%-270]; 
camera_angle = [180-50 0 50]%-extrinsicsInitialGuess(4)];%-270]; % minus x angle should be CCW from nadir % + z should be CW rotation around z
R = eul2rotm(deg2rad(camera_angle), 'XYZ');


tform = rigidtform3d(R,camera_point);
iP = world2img(world_point', tform, cameraParams_undistorted.Intrinsics );
iW = img2world2d(iP, tform, cameraParams_undistorted.Intrinsics);

camera_bound = [0 0; 3840 0; 3840 2160; 0 2160; 1920 1080];
iW_bounds = img2world2d(camera_bound, tform, cameraParams_undistorted.Intrinsics);
clf
subplot(121)
scatter3(world_point(1,:), world_point(2,:), world_point(3,:),100, colors(1,:), 'filled')
hold on
scatter3(iW(:,1), iW(:,2), 0, 200, colors(1,:))
scatter3(iW_bounds(:,1), iW_bounds(:,2), 0, 200, colors(2:6,:), '*')
plotCamera(Size=.2,Orientation = R, Location = camera_point)
xlabel('x ->')
ylabel('y ->')
zlabel('z ->')
set(gca, 'FontSize', 20)
%xlim([-5 5])
%ylim([-5 5])

subplot(122)
scatter(iP(:,1), -iP(:,2),100, colors(1,:), 'filled')
hold on
scatter(camera_bound(:,1), camera_bound(:,2), 100, colors(2:6,:), '*')
xlabel('x ->')
ylabel('<- y')
set(gca, 'YDir', 'reverse')
axis square
hold on
plot([0 cameraParams_undistorted.ImageSize(2) cameraParams_undistorted.ImageSize(2) 0 0], [0  0 cameraParams_undistorted.ImageSize(1) cameraParams_undistorted.ImageSize(1) 0])
