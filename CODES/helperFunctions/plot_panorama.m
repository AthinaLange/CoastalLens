function [panorama] = plot_panorama(images, intrinsics, extrinsics)
%   plot_panorama returns a panorama image from image sequence and corresponding extrinsics.
%% Syntax
%           [panorama] = plot_panorama(images, intrinsics, extrinsics)
%
%% Description
%   Args:
%           images (imageDatastore) : image dataset (m images) to use to construct panorama
%           intrinsics (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%           extrinsics (projtform2d) : [1 x m] projection for m images
%
%   Returns:
%           panorama (uint8 image): stitched panorama image
%
%% Example 1
% imageDirectory = './DATA/20211215_Torrey/01/images_2Hz/'
% images = imageDatastore(imageDirectory);
% [extrinsics] = get_extrinsics_fd(images, R.intrinsics, mask=R.mask);
% [panorama] = plot_panorama(images, R.intrinsics, extrinsics);
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024;

%% Data
assert(strcmp(class(images), 'matlab.io.datastore.ImageDatastore'), 'Error (plot_panorama): images must be a ImageDatastore object.')
assert(size(images.Files,1)==size(R.extrinsics_2d,2), 'Error (plot_panorama): Number of files in ''images'' and ''extrinsics'' must be the same.')
assert(isa(intrinsics, 'cameraIntrinsics'), 'Error (plot_panorama): intrinsics must be a cameraIntrinsics object.')
assert(isa(extrinsics, 'projtform2d'), 'Error (plot_panorama): extrinsics must be projtform2d array.')

%% Define panorama view
I = undistortImage(readimage(images, 1), intrinsics);
for i = 1:numel(extrinsics)
    imageSize(i,:) = size(I);
    [xlim(i,:), ylim(i,:)] = outputLimits(extrinsics(i), [1 imageSize(i,2)], [1 imageSize(i,1)]);
end % for i = 1:numel(extrinsics)

maxImageSize = max(imageSize);

% Find the minimum and maximum output limits.
xMin = min([1; xlim(:)]);
xMax = max([maxImageSize(2); xlim(:)]);

yMin = min([1; ylim(:)]);
yMax = max([maxImageSize(1); ylim(:)]);

% Width and height of panorama.
width  = round(xMax - xMin);
height = round(yMax - yMin);

% Initialize the "empty" panorama.
panorama = zeros([height width 3], 'like', I);
blender = vision.AlphaBlender('Operation', 'Binary mask', ...
    'MaskSource', 'Input port');

% Create a 2-D spatial reference object defining the size of the panorama.
xLimits = [xMin xMax];
yLimits = [yMin yMax];
panoramaView = imref2d([height width], xLimits, yLimits);
%% Build panorama
for i = 1:length(images.Files)

    I = undistortImage(readimage(images, i), intrinsics);

    % Transform I into the panorama.
    warpedImage = imwarp(I, extrinsics(i), 'OutputView', panoramaView);

    % Generate a binary mask.
    mask = imwarp(true(size(I,1),size(I,2)), extrinsics(i), 'OutputView', panoramaView);

    % Overlay the warpedImage onto the panorama.
    panorama = step(blender, panorama, warpedImage, mask);
end % for i = 1:length(images.Files)

end