function [extrinsics] = get_extrinsics_fd( images, intrinsics, varargin)
%
% get camera extrinsics using feature detection
%
%% Syntax
% 
%  [panorama, extrinsics] = get_extrinsics_fd(odir, oname, images, varargin)
%
%% Description 
% 
%   Args:
%           images (imageDatastore) : Stores file name of m images to process
%           intrinsics (cameraIntrinsics) : camera intrinsics object to undistort images
%           varargin :
%                       Method (string) : Feature type (default : 'SIFT')
%                       mask (double) :  binary mask. helps cut down on processing time.
%                       
%
%   Returns:
%          panorama (uint8) : constructed panorama image to show full field of view captured during flight
%          extrinsics (array) : 2D projective transformation between subsequent frames
%               
%
%
%% Example 1
%
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024; Last revision: XXX

viewId = 1;
I = im2gray(undistortImage(readimage(images, 1), intrinsics));
[m, n, ~] = size(I);


options.Method = 'SIFT'; % Feature type
options.mask = imcomplement(poly2mask([0 n n 0], [1 1 0 0], m, n)); % mask cutoff
options = parseOptions( options , varargin );

[I] = apply_binary_mask(I, options.mask);
[prevPoints] = detectFeatures(I, options.Method);
[prevFeatures, prevPoints] = extractFeatures(I, prevPoints);
tic
for viewId = 2:length(images.Files)
     
   %  if rem(viewId, 100) == 0
         disp(sprintf('viewId = %i', viewId))
    %     toc
     %end

    clear curr*
    I = im2gray(undistortImage(readimage(images, viewId), intrinsics));

    [I] = apply_binary_mask(I, options.mask);
    imageSize(viewId,:) = size(I);

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
end

extrinsics = tforms;

close all
end
