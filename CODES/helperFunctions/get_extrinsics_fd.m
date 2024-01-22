function [panorama, extrinsics] = get_extrinsics_fd(odir, oname, images, varargin)
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
%           odir (string) : location of day/flight folder to load and save data
%           oname (string) : prefix name for current day/flight to load and save data
%           images (imageDatastore) : Stores file name of m images to process
%           varargin :
%                       Method (string) : Feature type (default : 'SIFT')
%                       cutoff (double) :  vertical pixel cutoff for mask. helps cut down on processing time.
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


options.Method = 'SIFT'; % Feature type
options.cutoff = 1; % mask cutoff
options = parseOptions( options , varargin );



viewId = 1;
I = im2gray(readimage(images, 1));
[m, n, ~] = size(I);
mask = imcomplement(poly2mask([0 n n 0], [options.cutoff options.cutoff 0 0], m, n));
[I] = apply_binary_mask(I, mask);
[prevPoints] = detectFeatures(I, options.Method);
[prevFeatures, prevPoints] = extractFeatures(I, prevPoints);
tic
for viewId = 2:length(images.Files)
     disp(sprintf('viewId = %i', viewId))
     if rem(viewId, 100) == 0
         toc
     end

    clear curr*
    I = im2gray(readimage(images, viewId));

    [I] = apply_binary_mask(I, mask);
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

for i = 1:numel(tforms)
    [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 imageSize(i,2)], [1 imageSize(i,1)]);
end

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


% Create the panorama.
for i = 1:length(images.Files)

    I = readimage(images, i);

    % Transform I into the panorama.
    warpedImage = imwarp(I, tforms(i), 'OutputView', panoramaView);

    % Generate a binary mask.
    mask = imwarp(true(size(I,1),size(I,2)), tforms(i), 'OutputView', panoramaView);

    % Overlay the warpedImage onto the panorama.
    panorama = step(blender, panorama, warpedImage, mask);
end

extrinsics = tforms;

%  Save File
figure(1);clf
imshow(panorama)
saveas(gca, fullfile(odir, 'Processed_data', [oname '_Panorama.png']))
close all
end
