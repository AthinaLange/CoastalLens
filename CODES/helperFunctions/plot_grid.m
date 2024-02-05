function plot_grid(Products, I, intrinsics, worldPose)
%   plot_grid plots grid points on oblique image as specified output from define_grid.
%% Syntax
%           plot_grid(Products, I, intrinsics, worldPose)
%
%% Description
%   Args:
%           Products (structure) : Single Products object. All necessary variables given in define_grid
%           I (uint8 image) : Oblique image
%           intrinsics (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%           worldPose (rigidtform3d) : worldPose of oblique image
%
%   Returns:
%
%   Function dependencies:
%       getCoords
%       ll_to_utm
%
%% Example 1
% plot_grid(Products(1), R.I, R.intrinsics, R.worldPose)
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Data
assert(isa(Products, 'structure'), 'Error (plot_grid): Products must be a structure.')
assert(size(Products,2)==1, 'Error (plot_grid): Products must be a single object structure. Pass as Products(pp).')
assert(isa(I, 'uint8'), 'Error (plot_grid): I must be a uint8 image.')
assert(isa(intrinsics, 'cameraIntrinsics'), 'Error (plot_grid): intrinsics must be a cameraIntrinsics object.')
assert(isa(worldPose, 'rigidtform3d'), 'Error (plot_grid): worldPose must be a rigidtform3d object.')

%% Get coordinates and pixel location
[xyz,~,~,~] = getCoords(Products);
[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);
aa=xyz-[x2 y2 0];
iP = round(world2img(xyz, pose2extr(worldPose), intrinsics));

%% Plot
figure(1);clf
image(I)
hold on
scatter(iP(:,1), iP(:,2), 25, 'filled')
xlim([0 size(I,2)])
ylim([0 size(I,1)])
id=find(min(abs(aa(:,[1 2])))==abs(aa(:,[1 2])));
scatter(iP(id(1),1), iP(id(1),2),50, 'g', 'filled')
legend('Grid', 'Origin')
set(gca, 'FontSize', 20)
end