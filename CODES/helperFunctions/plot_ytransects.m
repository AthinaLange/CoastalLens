function plot_ytransects(Products, I, intrinsics, extrinsics)
%  plot_ytransects plots along-shore transects on oblique image as specified output from define_ytransect.
%% Syntax
%           plot_ytransects(Products, I, intrinsics, worldPose)
%
%% Description
%   Args:
%           Products (structure) : Single Products object. All necessary variables given in define_ytransect.
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
% plot_ytransect(Products(1), R.I, R.intrinsics, R.worldPose)
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Data
assert(isa(Products, 'structure'), 'Error (plot_ytransects): Products must be a structure.')
assert(isa(I, 'uint8'), 'Error (plot_ytransects): I must be a uint8 image.')
assert(isa(intrinsics, 'cameraIntrinsics'), 'Error (plot_ytransects): intrinsics must be a cameraIntrinsics object.')
assert(isa(worldPose, 'rigidtform3d'), 'Error (plot_ytransects): worldPose must be a rigidtform3d object.')

%% Get coordinates and pixel location
ids_ytransect = find(contains(extractfield(Products, 'type'), 'yTransect'));

figure(6);clf
hold on
imshow(I)
hold on
title('yTransect')
jj=0;
for pp = ids_ytransect % repeat for all ytransects
    jj=jj+1;
    [xyz,~,~,~] = getCoords(Products(pp));
    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    aa=xyz-[x2 y2 0];
    iP = round(world2img(xyz, pose2extr(extrinsics), intrinsics));

    scatter(iP(:,1), iP(:,2), 25, 'filled')
    xlim([0 size(I,2)])
    ylim([0 size(I,1)])

    le{jj}= [Products(pp).type ' - y = ' char(string(Products(pp).x)) 'm'];

end % for pp = ids_ytransect
legend(le)
end