intrinsics = cameraIntrinsics([2672.9 2664.4],[1920 1080],[2160 3840])
%[R] = CIRNangles2R(deg2rad(180),deg2rad(20), deg2rad(270)) % 1st angle is swing CW (180 has camera up correctly), % 2nd is pitch up from nadir % 3rd is azimuth CW from looking along +y
%[R] = CIRNangles2R(extrinsics(4), extrinsics(5), extrinsics(6)) % 1st angle is swing CW (180 has camera up correctly), % 2nd is pitch up from nadir % 3rd is azimuth CW from looking along +y
[R] = CIRNangles2R(deg2rad(0), deg2rad(10), deg2rad(0)) % 1st angle is swing CW (180 has camera up correctly), % 2nd is pitch up from nadir % 3rd is azimuth CW from looking along +y
worldPose = rigidtform3d(R, [0 0 70])
worldPoints = [100 0 0]
P = cameraProjection(intrinsics,(worldPose));%P=P/P(3,4);
%%
% --------- Project camera bounds into world ----------
clear w_bounds*
%[w_bounds] = img2world2d(camera_bounds, pose2extr(worldPose), intrinsics)
c_bounds = world2img(worldPoints, worldPose,intrinsics)

% CIRNc
extrinsics(1:2)=[0 0]
%[xyz] = distUV2XYZ(intrinsics_CIRN,extrinsics,camera_bounds', 'z',zeros(1,size(camera_bounds,1)))
[UVd,flag] = xyz2DistUV(intrinsics_CIRN,extrinsics,[worldPoints])
UVd = reshape(UVd, [],2);
%

figure(3);%clf
%plotCamera(AbsolutePose=worldPose, AxesVisible=true)
scatter3(worldPose.Translation(1), worldPose.Translation(2), worldPose.Translation(3), 100, 'filled')
grid on
hold on
for ii = 1:size(worldPoints,1)
    scatter3(worldPoints(ii,1), worldPoints(ii,2), 0,100, 'LineWidth', 3)
end
xlabel('X')
ylabel('Y')
title('World View')
set(gca, 'FontSize', 30)%, 'YDir', 'reverse')



figure(2);%clf
title('Camera View')
hold on
for ii = 1:size(worldPoints,1)
    %scatter(camera_bounds(ii,1), camera_bounds(ii,2), 100, colors(ii,:), 'filled')
    scatter(c_bounds(ii,1), c_bounds(ii,2), 100, 'filled')

    scatter(UVd(ii,1), UVd(ii,2), 100, colors(ii,:))
end
legend('MATLAB', 'CIRN')
set(gca, 'YDir', 'reverse', 'FontSize', 30)
%xlim([-1 3841])
%ylim([-1 2161])



%%
intrinsics = cameraIntrinsics([2672.9 2664.4],[1920 1080],[2160 3840])
%[R] = CIRNangles2R(deg2rad(180),deg2rad(70), deg2rad(270)) % 1st angle is swing CW (180 has camera up correctly), % 2nd is pitch up from nadir % 3rd is azimuth CW from looking along +y
[R] = CIRNangles2R(extrinsics(4), extrinsics(5), extrinsics(6)) % 1st angle is swing CW (180 has camera up correctly), % 2nd is pitch up from nadir % 3rd is azimuth CW from looking along +y
worldPose = rigidtform3d(R, [0 0 70])
camera_bounds = [0 0; 3840 0; 3840 2160; 0 2160; 1920 1080]
P = cameraProjection(intrinsics,(worldPose));%P=P/P(3,4);

% --------- Project camera bounds into world ----------
clear w_bounds*
[w_bounds] = img2world2d(camera_bounds, pose2extr(worldPose), intrinsics)

% CIRN
extrinsics(1:2)=[0 0]
[xyz] = distUV2XYZ(intrinsics_CIRN,extrinsics,camera_bounds', 'z',zeros(1,size(camera_bounds,1)))

%

figure(3);clf
%plotCamera(AbsolutePose=worldPose, AxesVisible=true)
scatter3(worldPose.Translation(1), worldPose.Translation(2), worldPose.Translation(3), 100, 'filled')
grid on
hold on
for ii = 1:size(camera_bounds,1)
    scatter3(w_bounds(ii,1), w_bounds(ii,2), 0,100, colors(ii,:), 'LineWidth', 3)
    scatter3(xyz(ii,1), xyz(ii,2), 0,100, colors(ii,:), 'filled')
end
    plot3(w_bounds([1:4 1],1), w_bounds([1:4 1],2), [0 0 0 0 0], 'r-')
    plot3(xyz([1:4 1],1), xyz([1:4 1],2), [0 0 0 0 0], 'k-')

xlabel('X')
ylabel('Y')
title('World View')
set(gca, 'FontSize', 30)%, 'YDir', 'reverse')



figure(2);clf
title('Camera View')
hold on
for ii = 1:size(camera_bounds,1)
    scatter(camera_bounds(ii,1), camera_bounds(ii,2), 100, colors(ii,:), 'filled')
end
set(gca, 'YDir', 'reverse', 'FontSize', 30)
xlim([-1 3841])
ylim([-1 2161])
%%
% P = cameraProjection(intrinsics,(worldPose)); %P=P/P(3,4)
% tidez=0
% for ii = 1:size(camera_bounds,1)
%     w_bounds2(ii,:) = P* [camera_bounds(ii,:) tidez 1]';
% end
% w_bounds2 = w_bounds2./w_bounds2(:,3)
% 
% 
% U = camera_bounds(:,1)
% V = camera_bounds(:,2)
% % Convert P to DLT Coefficients
% A = P(1,1);
% B = P(1,2);
% C = P(1,3);
% D = P(1,4);
% E = P(3,1);
% F = P(3,2);
% G = P(3,3);
% H = P(2,1);
% J = P(2,2);
% K = P(2,3);
% L = P(2,4);
% 
% % Convert Coefficients to Rearranged Combined Coefficients For Solution
% M = (E*U - A);
% N = (F*U - B);
% O = (G*U - C);
% W = (D - U);
% Q = (E*V - H);
% R = (F*V - J);
% S = (G*V - K);
% T = (L - V);
% 
% 
% Z =  0
% X = ((N.*S - R.*O).*Z + (R.*W - N.*T))./(R.*M - N.*Q)
% Y = ((M.*S - Q.*O).*Z + (Q.*W - M.*T))./(Q.*N - M.*R)




%%
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/CPG_data/origin_Torrey.mat')
[UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(origin_grid(1), origin_grid(2));
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/worldPose.mat')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IO.mat', 'cameraParams')
intrinsics = cameraParams.Intrinsics;
grid=worldPose.Translation(1:2);


%% Project grid points into image with cameraProjection matrix
aa=rad2deg(rotm2eul(wP.R));
worldPose = rigidtform3d()


P = cameraProjection(intrinsics,pose2extr(worldPose)); P=P/P(3,4)
grid_bounds = [0 300; -500 300; -500 -300; 0 -300; 0 0]; grid_bounds =grid_bounds + [UTMEasting UTMNorthing];
for ii = 1:size(grid_bounds,1)
    aa(ii,:) = P* [grid_bounds(ii,:) tidez 1]';
end
aa = aa./aa(:,3)

%% Project image corner points into z=0 plane

U = [0 3840 3840 0 2150]'
V = [0 0 2160 2160 1750]'
% Convert P to DLT Coefficients
A = P(1,1);
B = P(1,2);
C = P(1,3);
D = P(1,4);
E = P(3,1);
F = P(3,2);
G = P(3,3);
H = P(2,1);
J = P(2,2);
K = P(2,3);
L = P(2,4);

% Convert Coefficients to Rearranged Combined Coefficients For Solution
M = (E*U - A);
N = (F*U - B);
O = (G*U - C);
W = (D - U);
Q = (E*V - H);
R = (F*V - J);
S = (G*V - K);
T = (L - V);


Z =  0
X = ((N.*S - R.*O).*Z + (R.*W - N.*T))./(R.*M - N.*Q);
Y = ((M.*S - Q.*O).*Z + (Q.*W - M.*T))./(Q.*N - M.*R);



figure(2);clf
image(I)
hold on
for ii = 1:length(aa)
    scatter(aa(ii,1), aa(ii,2), 100,colors(ii,:), 'filled')
    scatter(U(ii),V(ii), 100,colors(ii,:), 'LineWidth', 3)
end
legend
plot(aa([1:4 1],1), aa([1:4 1],2),'Color', colors(ii,:), 'LineWidth', 3)

xlim([-1 3841])
ylim([-1 2161])





figure(3);clf
plotCamera(absolutePose=worldPose)
hold on
for ii = 1:length(grid_bounds)
    scatter(grid_bounds(ii,1), grid_bounds(ii,2), 100, colors(ii,:), 'filled')
    scatter(X(ii), Y(ii), 100, colors(ii,:), 'LineWidth', 3)
end

plot3(grid_bounds([1:4 1],1), grid_bounds([1:4 1],2), 0* grid_bounds([1:4 1],2),'Color', 'k', 'LineWidth', 3)
grid on
%%

aa=rad2deg(rotm2eul(worldPose.R));% aa(2)=aa(2)+90;
worldPose=rigidtform3d(eul2rotm(deg2rad(aa)), worldPose.Translation); clear aa
camPoints =[0 0; 3840 0; 3840 2160; 0 2160; 2150 1750]; 
worldPoints=img2world2d(camPoints, pose2extr(worldPose), intrinsics)
%%
figure(2);clf
image(I)
hold on
for ii = 1:5
    scatter(camPoints(ii,1), camPoints(ii,2), 100, 'filled')
end
legend
set(gca, 'YDir', 'reverse')
xlim([-1 3841])
ylim([-1 2161])
%%
figure(3);clf
plotCamera(AbsolutePose=worldPose, AxesVisible=true)
grid on
hold on
for ii = 1:4
%scatter3(worldPoints(ii,1), worldPoints(ii,2),0, 50, colors(ii,:), 'filled')
scatter3(grid_bounds(ii,1), grid_bounds(ii,2),0, 50, colors(ii,:), 'filled')

end
legend
%plot(worldPoints([1:4 1],1), worldPoints([1:4 1],2))
xlabel('x')
ylabel('y')
plot3(worldPose.Translation(1), worldPose.Translation(2), worldPose.Translation(3), '.', 'MarkerSize', 50)
for ii = 1:4
%plot3([worldPoints(ii,1) worldPose.Translation(1)], [worldPoints(ii,2) worldPose.Translation(2)], [0 worldPose.Translation(3)], 'k-', 'LineWidth', 2)
end
%%
