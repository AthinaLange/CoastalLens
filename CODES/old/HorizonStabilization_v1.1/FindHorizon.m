function [thetaMax, rMax, peakFrac, varargout] = FindHorizon(frames,ROI,method)
% FindHorizon Find horizon in single images or video frames.  Requires
% Matlab Computer Vision System Toolbox (preferred). For implementation
% with Image Processing Toolbox, use FindHorizonAlternate.
%
%   [thetaMax,rMax,peakFrac] = FindHorizon(frames,ROI,method) finds the
%   horizon line as the maximum in the Hough Transform of frames, an MxNxP
%   array of grayscale images.  ROI is a 1x4 vector of form
%   [v_min,u_min,v_max,u_max] defining the region of interest for the Hough
%   Transform. method is a string argument defining the edge detection
%   method, either 'sobel' or 'canny'. Both use an automatic threshold.
%   Outputs thetaMax and rMax are 1xP vectors resulting from the
%   maximization of the Hough Transform. thetaMax is in radians, with range
%   0<=thetaMax<=pi and resolution pi/360 (half a degree). rMax is in
%   pixels, with 1 pixel resolution. peakFrac is the ratio of the second
%   highest local maxima to the absolute maximum, to be used for quality
%   control
%
%   [thetaMax,rMax,peakFrac,edgeMatrix] = FindHorizon(frames,ROI,method)
%   ouputs the binary array edgeMatrix, resulting from the edge detection.
%
%   [thetaMax,rMax,peakFrac,edgeMatrix,ht,theta,rho] =
%   FindHorizon(frames,ROI,method) ouputs the Hough Transform array, of
%   size (2*ceil(sqrt(N^2+M^2))+1)x360xP, and theta and rho arrays of size
%   (2*ceil(sqrt(N^2+M^2))+1)x360.
%
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.

% check for computer vision system toolbox
v = ver;
if ~any(strcmp(cellstr(char(v.Name)), 'Computer Vision System Toolbox'))
    error('Computer Vision System Toolbox not available.  Use FindHorizonAlternate instead')
end

% edge-finding object
if strcmp(method,'sobel')
    edgeObj = vision.EdgeDetector('Method','Sobel','BinaryImageOutputPort',true,'ThresholdSource','Auto');
elseif strcmp(method,'canny')
    edgeObj = vision.EdgeDetector('Method','Canny','ThresholdSource','Auto','NonEdgePixelsPercentage',95);
else
    error('method must be either ''sobel'' or ''canny''')
end
% hough transform object
houghTransObj = vision.HoughTransform(pi/360,'ThetaRhoOutputPort',true);

% max line object
[nv, nu, numFrames] = size(frames);
rBins = 2*ceil(sqrt((nu-1)^2+(nv-1)^2))+1;
thetaBins = 360;
rBuff = 10;  % buffer for finding second Hough peak
thetaBuff = 5;  % buffer for finding second Hough peak
houghMaxObj = vision.LocalMaximaFinder(2,[2*rBuff+1 2*thetaBuff+1],'HoughMatrixInput',true);

nout = max(nargout,1) - 3;

if nout==4
    edgeMatrix = false(nv,nu,numFrames);
    ht = nan(rBins,thetaBins,numFrames);
elseif nout==1
    edgeMatrix = false(nv,nu,numFrames);
elseif nout~=0
    error('Incorrect number of output arguments')
end
thetaMax = zeros(numFrames,1);
rMax = zeros(numFrames,1);
peakFrac = zeros(numFrames,1);
edgeMatI = false(nv,nu);

for i=1:numFrames
    fprintf('Finding Horizon in Frame %d of %d\n',i,numFrames)
    % Crop images
    VideoFrameCrop = double(frames(ROI(1):ROI(3),ROI(2):ROI(4),i));
    
    % Find edges in cropped image
    edgeMatI(ROI(1):ROI(3),ROI(2):ROI(4)) = step(edgeObj,VideoFrameCrop);
    if nout==1 || nout==4
        edgeMatrix(:,:,i) = edgeMatI;
    end
    
    % Run edge output through hough transform
    [htI,theta,r] = step(houghTransObj,edgeMatI);
    theta(theta<0)=pi+theta(theta<0);
    theta = [theta((floor(length(theta)/2)+1):end),theta(1:floor(length(theta)/2))];
    htI = [htI(:,(floor(length(theta)/2)+1):end),htI(end:-1:1,1:floor(length(theta)/2))];
    if nout==4
        ht(:,:,i) = htI;
    end
    
    % Find the index of max in Hough matrix
    idx = step(houghMaxObj,htI);
    if isempty(idx)
        thetaMax(i) = nan;
        rMax(i) = nan;
        peakFrac(i) = nan;
    else
        thetaMaxInd = idx(1,1);
        rMaxInd = idx(1,2);
        thetaMaxInd2 = idx(2,1);
        rMaxInd2 = idx(2,2);
        peakFrac(i) = htI(rMaxInd2,thetaMaxInd2)/htI(rMaxInd,thetaMaxInd);
        thetaMax(i) = theta(thetaMaxInd);
        rMax(i) = r(rMaxInd);
    end
end

if nout==4
    varargout{1} = edgeMatrix;
    varargout{2} = ht;
    varargout{3} = theta;
    varargout{4} = r;
elseif nout==1
    varargout{1} = edgeMatrix;
end

release(edgeObj);
release(houghTransObj);
release(houghMaxObj);
