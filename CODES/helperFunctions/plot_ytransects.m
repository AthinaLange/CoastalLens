function plot_ytransects(Products, I, intrinsics, worldPose, varargin )
%  plot_ytransects plots along-shore transects on oblique image as specified output from define_ytransect.
%% Syntax
%           plot_ytransects(Products, I, intrinsics, worldPose)
%
%% Description
%   Args:
%           Products (structure) : Products object. All necessary variables given in define_ytransect.
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
% plot_ytransect(Products, R.I, R.intrinsics, R.worldPose)
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Nov 2023;

%% Data
assert(isa(Products, 'struct'), 'Error (plot_ytransects): Products must be a structure.')
assert(isa(I, 'uint8'), 'Error (plot_ytransects): I must be a uint8 image.')
assert(isa(intrinsics, 'cameraIntrinsics'), 'Error (plot_ytransects): intrinsics must be a cameraIntrinsics object.')
assert(isa(worldPose, 'rigidtform3d'), 'Error (plot_ytransects): worldPose must be a rigidtform3d object.')

options.DEM = [];
options = parseOptions( options , varargin );
if ~isempty(options.DEM)
    DEM = options.DEM;
end
%% Get coordinates and pixel location
ids_ytransect = find(ismember(string({Products.type}), 'yTransect'));

figure(6);clf
hold on
imshow(I)
hold on
title('yTransect')
jj=0;
for pp = ids_ytransect % repeat for all ytransects
    jj=jj+1;
    if exist('DEM', 'var')
        [xyz,~,~,~,~,~] = getCoords_DEM(Products(pp), DEM);
    else
        [xyz,~,~,~,~,~] = getCoords(Products(pp));
    end
    iP = round(world2img(xyz, pose2extr(worldPose), intrinsics));

    scatter(iP(:,1), iP(:,2), 25, 'filled')
    xlim([0 size(I,2)])
    ylim([0 size(I,1)])

    le{jj}= [Products(pp).type ' - y = ' char(string(Products(pp).x)) 'm'];

    set(gca, 'FontSize', 20)
end % for pp = ids_ytransect
legend(le)
end