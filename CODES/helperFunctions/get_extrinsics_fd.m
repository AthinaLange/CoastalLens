function [extrinsics] = get_extrinsics_fd( images, intrinsics, varargin)
% get_extrinsics_fd returns 2D projective transformation between image frames using feature detection.
%% Syntax
%  [extrinsics] = get_extrinsics_fd(images, intrinsics)
%  [extrinsics] = get_extrinsics_fd(images, intrinsics, Method = 'SIFT')
%  [extrinsics] = get_extrinsics_fd(images, intrinsics, mask = R.mask)
%  [extrinsics] = get_extrinsics_fd(images, intrinsics, Method = 'SIFT', mask = R.mask)
%
%% Description
%
%   Args:
%           images (imageDatastore) : Stores file name of m images to process
%           intrinsics (cameraIntrinsics) : camera intrinsics object to undistort images
%           varargin :
%                       Method (string) : Feature type (default : 'SIFT')
%                       mask (logical) :  binary mask (same dimensions as images). helps cut down on processing time.
%
%   Returns:
%          extrinsics (array) : [1 x m] 2D projective transformation between subsequent frames
%
%
%% Example 1
% intrinsics = cameraParams.Intrinsics;
% R.I = readimage('DATA/20211215_Torrey/01/DJI_0001.JPG');
% [R.mask] = select_ocean_mask(R.I);
% imageDirectory = './DATA/20211215_Torrey/01/images_2Hz/'
% images = imageDatastore(imageDirectory);
% [extrinsics] = get_extrinsics_fd(images, intrinsics, mask = R.mask)
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jan 2024;

%% Data
assert(strcmp(class(images), 'matlab.io.datastore.ImageDatastore'), 'Error (get_extrinsics_fd): images must be a ImageDatastore object.')
assert(isa(intrinsics, 'cameraIntrinsics'), 'Error (get_extrinsics_fd): intrinsics must be a cameraIntrinsics object.')

I = im2gray(undistortImage(readimage(images, 1), intrinsics));
[m, n, ~] = size(I);

options.Method = 'SIFT'; % Feature type
options.mask = imcomplement(poly2mask([0 n n 0], [1 1 0 0], m, n)); % mask cutoff
options = parseOptions( options , varargin );

assert(isa(options.Method, 'char') || isa(options.Method, 'string'), 'Error (get_extrinsics_fd): Method must be a character string.')
assert(contains(options.Method, {'SIFT' , 'BRISK', 'ORB', 'KAZE'}), 'Error (get_extrinsics_fd): Method must be one of the following allowed features: SIFT, BRISK, ORB, KAZE or SURF.')

assert(isa(options.mask, 'logical'), 'Error (get_extrinsics_fd): mask must be an binary mask.')
assert(sum(size(options.mask) == size(I, [1 2]))==2, 'Error (get_extrinsics_fd): mask must be the same size as I.')


%% Find features in 1st image
[I] = apply_binary_mask(I, options.mask);
if size(I,3) == 3 % still rgb
    I = im2gray(I);
end % if size(I,3) == 3
[prevPoints] = detectFeatures(I, options.Method);
[prevFeatures, prevPoints] = extractFeatures(I, prevPoints);

%% Find corresponding features in subsequent images
for viewId = 2:length(images.Files)

    if rem(viewId, 100) == 0
        fprintf('viewId = %i\n', viewId)
    end % if rem(viewId, 100) == 0

    clear curr*
    I = im2gray(undistortImage(readimage(images, viewId), intrinsics));

    [I] = apply_binary_mask(I, options.mask);

    % Detect and extract SURF features for I(n).
    [currPoints] = detectFeatures(I, options.Method);
    [currFeatures, currPoints] = extractFeatures(I, currPoints);

    % Find correspondences between I(n) and I(n-1).
    indexPairs = matchFeatures(currFeatures, prevFeatures, 'Unique', true);

    matchedPoints = currPoints(indexPairs(:,1), :);
    matchedPointsPrev = prevPoints(indexPairs(:,2), :);


    % Estimate the transformation between I(n) and I(n-1).
    tforms(viewId) = estgeotform2d(matchedPoints, matchedPointsPrev,...
        'projective', 'Confidence', 99.9, 'MaxNumTrials', 2000);

    % Compute T(1) * T(2) * ... * T(n-1) * T(n).
    tforms(viewId).A = tforms(viewId-1).A * tforms(viewId).A;

    clear prev*
    prevPoints = currPoints;
    prevFeatures = currFeatures;
end % for viewId = 2:length(images.Files)

extrinsics = tforms;

close all
end
