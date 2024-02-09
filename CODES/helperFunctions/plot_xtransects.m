function plot_xtransects(Products, I, intrinsics, worldPose)
%   plot_xtransects plots cross-shore transects on oblique image as specified output from define_xtransect.
%% Syntax
%           plot_xtransects(Products, I, intrinsics, worldPose)
%
%% Description
%   Args:
%           Products (structure) : Products object. All necessary variables given in define_xtransect.
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
% plot_xtransects(Products, R.I, R.intrinsics, R.worldPose)
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Data
assert(isa(Products, 'struct'), 'Error (plot_xtransects): Products must be a structure.')
assert(isa(I, 'uint8'), 'Error (plot_xtransects): I must be a uint8 image.')
assert(isa(intrinsics, 'cameraIntrinsics'), 'Error (plot_xtransects): intrinsics must be a cameraIntrinsics object.')
assert(isa(worldPose, 'rigidtform3d'), 'Error (plot_xtransects): worldPose must be a rigidtform3d object.')

%% Get coordinates and pixel location
ids_xtransect = find(ismember(string({Products.type}), 'xTransect'));

figure(5);clf
hold on
imshow(I)
hold on
title('Timestack')
jj=0;
for pp = ids_xtransect % repeat for all xtransects
    jj=jj+1;
    [xyz,~,~,~,~,~] = getCoords(Products(pp));
    iP = round(world2img(xyz, pose2extr(worldPose), intrinsics));

    scatter(iP(:,1), iP(:,2), 25, 'filled')
    xlim([0 size(I,2)])
    ylim([0 size(I,1)])

    le{jj}= [Products(pp).type ' - x = ' char(string(Products(pp).y)) 'm'];
    
    set(gca, 'FontSize', 20)
end % for pp = ids_xtransect 
legend(le)
end