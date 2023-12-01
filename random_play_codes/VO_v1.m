

clear all
close all

imageDirectory = '/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/images_10Hz/'
images = imageDatastore(imageDirectory)


%%

% Create an empty imageviewset object to manage the data associated with each view.
vSet = imageviewset;

% Read and display the first image.
Irgb = readimage(images, 1);
player = vision.VideoPlayer(Position=[20, 400,2000, 1200]);
step(player, Irgb);
%% Load in Intrinsics
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IO.mat', 'cameraParams')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IOEOInitial.mat', 'extrinsics')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IOEOInitial.mat', 'intrinsics')
intrinsics_cirn = intrinsics;
intrinsics = cameraParams.Intrinsics;
%% Get World Poses - construct groundtruth for scale
load('/Users/athinalange/Documents/MATLAB/Examples/R2023a/vision/VisualOdometryExample/GT_base')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/pointhandles.mat')
for ii = 1:size(pointhandles,1)
    worldPose = estworldpose(squeeze(pointhandles(ii,:,:)),gcp_xyz, cameraParams.Intrinsics);
    
    if ii == 1
        tt = worldPose.Translation;
    end
        groundTruthPoses.ViewId(ii) = ii;
        groundTruthPoses.Location{ii} = worldPose.Translation - tt;
        groundTruthPoses.Orientation{ii} = worldPose.R;
end
%% Get World Poses from MATLAB
        
for k=1:size(pointhandles,1)
    if k == 1
        extrinsics_old = extrinsics;
    else
        extrinsics_old=extrinsicsVariable(k-1,:);
    end
    clear extrinsics_new
    extrinsicsKnownsFlag = [0 0 0 0 0 0];
    [extrinsics_new, ~] = extrinsicsSolver(extrinsics_old, extrinsicsKnownsFlag, intrinsics_cirn, squeeze(pointhandles(k,:,:)), gcp_xyz);
    extrinsicsVariable(k,:)=extrinsics_new;
end % for k = 2:length(L)

groundTruth_CIRN = groundTruthPoses;
for ii = 1:size(pointhandles,1)
    if ii == 1
        tt = extrinsicsVariable(ii,1:3);
    end
    groundTruthPoses.ViewId(ii) = ii;
    groundTruthPoses.Location{ii} = extrinsicsVariable(ii,1:3) - tt;
    groundTruthPoses.Orientation{ii} =  eul2rotm(extrinsicsVariable(ii,4:6), 'ZYZ');
end
%%
figure(1);clf
imshow(Irgb)
hold on
scatter(pointhandles(1,:,1), pointhandles(1,:,2), 100, 'r', 'filled')
%% Get Absolute Position of first image

prevI = undistortImage(im2gray(Irgb), intrinsics); 
cutoff = round(size(Irgb,1)*(3/4)); %prevI = prevI(cutoff:end,:);

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 2000;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

% Add the first view. Place the camera associated with the first view
% at the origin, oriented along the Z-axis.
viewId = 1;

vSet = addView(vSet, viewId, rigidtform3d(groundTruthPoses.Orientation{1}, groundTruthPosees.Location{1}), Points=prevPoints);
%%
figure(1);clf
imshow(Irgb)
hold on
plot(vSet.Views.Points{1})
%% Do 2nd image
% viewId = 2;
% Irgb = readimage(images, viewId);
% step(player, Irgb);
% 
% % Convert to gray scale and undistort.
% I = undistortImage(im2gray(Irgb), intrinsics);
% cutoff = round(size(I,1)*(3/4)); 
% 
% % Match features between the previous and the current image.
% [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints);
% 
% % Estimate the pose of the current view relative to the previous view.
% [relPose, inlierIdx] = helperEstimateRelativePose(...
%     prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)), intrinsics);
% 
% % Exclude epipolar outliers.
% indexPairs = indexPairs(inlierIdx, :);
% figure(1);clf
% showMatchedFeatures(readimage(images, 1), readimage(images,2), prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
% %%
% % Add the current view to the view set.
% vSet = addView(vSet, viewId, Points=currPoints);
% 
% % Store the point matches between the previous and the current views.
% vSet = addConnection(vSet, viewId-1, viewId, Matches=indexPairs);

%% Correct for scale
%[~, scaleFactor] = helperNormalizeViewSet(vSet, groundTruth_CIRN);

 [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints);


%% Continue onto 3rd image
for viewId = 2:50
    % Read and display the next image
    Irgb = readimage(images, viewId);
    step(player, Irgb);
    
    % Convert to gray scale and undistort.
    I = undistortImage(im2gray(Irgb), intrinsics);
    
    % Match points between the previous and the current image.
   [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints);

    % Eliminate outliers from feature matches.
    [relPose, inlierIdx] = helperEstimateRelativePose(prevPoints(indexPairs(:,1)),...
        currPoints(indexPairs(:, 2)), intrinsics);
    indexPairs = indexPairs(inlierIdx, :);
    
    % Triangulate points from the previous two views, and find the 
    % corresponding points in the current view.
    % [worldPoints, imagePoints] = helperFind3Dto2DCorrespondences(vSet,...
    %     intrinsics, indexPairs, currPoints);
    % 
    % % Since RANSAC involves a stochastic process, it may sometimes not
    % % reach the desired confidence level and exceed maximum number of
    % % trials. Disable the warning when that happens since the outcomes are
    % % still valid.
    % warningstate = warning('off','vision:ransac:maxTrialsReached');
    % 
    % % Estimate the world camera pose for the current view.
    % absPose = estworldpose(imagePoints, worldPoints, intrinsics);
    % 
    % % Restore the original warning state
    % warning(warningstate)
    % 
    % Add the current view to the view set.
    %vSet = addView(vSet, viewId, absPose, Points=currPoints);
    vSet = addView(vSet, viewId, Points=currPoints);
    
    % Store the point matches between the previous and the current views.
    vSet = addConnection(vSet, viewId-1, viewId, Matches=indexPairs);    
    
   % if mod(viewId, 10) == 0        
   %      % Find point tracks in the last 15 views and triangulate.
   %      windowSize = 15;
   %      startFrame = max(1, viewId - windowSize);
   %      tracks = findTracks(vSet, startFrame:viewId);
   %      camPoses = poses(vSet, startFrame:viewId);
   %      [xyzPoints, reprojErrors] = triangulateMultiview(tracks, camPoses, intrinsics);
   % 
   %      % Hold the first two poses fixed, to keep the same scale. 
   %      fixedIds = [startFrame, startFrame+1];
   % 
   %      % Exclude points and tracks with high reprojection errors.
   %      idx = reprojErrors < 2;
   % 
   %      [~, camPoses] = bundleAdjustment(xyzPoints(idx, :), tracks(idx), ...
   %          camPoses, intrinsics, FixedViewIDs=fixedIds, ...
   %          PointsUndistorted=true, AbsoluteTolerance=1e-12,...
   %          RelativeTolerance=1e-12, MaxIterations=200);
   % 
   %      vSet = updateView(vSet, camPoses); % Update view set.
   % end

    prevI = I;
    prevFeatures = currFeatures;
    prevPoints   = currPoints;  
end
%% Do Scale Shift at the end to all frames

   % camPoses = poses(vSet);
   % 
   %  % Rotate the poses so that the first camera points along the Z-axis
   %  R = camPoses.AbsolutePose(1).R;
   %  for i = 1:height(camPoses)
   %      % Scale the locations
   %      camPoses.AbsolutePose(i).Translation = camPoses.AbsolutePose(i).Translation * scaleFactor;
   %      camPoses.AbsolutePose(i).R = R' *camPoses.AbsolutePose(i).R;
   %  end
   % 
   %  vSet = updateView(vSet, camPoses);
    %% Plot Camera motion

%clf;
for viewId = 1:15

    clf
    
    plotCamera(AbsolutePose = vSet.Views.AbsolutePose(viewId))
    grid on
    xlim([-5 5])
    ylim([-5 5])
    zlim([-5 5])
    xlabel('x')
    ylabel('y')
    hold on
    trajectoryEstimated = plot3(0, 0, 0, "g-");
    view(-90,90)
        title(viewId)
    locations = vertcat(poses(vSet).AbsolutePose.Translation);
    set(trajectoryEstimated, 'XData', locations(:,1), 'YData', ...
    locations(:,2), 'ZData', locations(:,3));
    camEstimated.AbsolutePose = poses(vSet).AbsolutePose(viewId);
    pause(0.5)
end

%% FUNCTIONS

function [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints)
    % Detect and extract features from the current image.
    currPoints   = detectSURFFeatures(I(cutoff:end,:), 'MetricThreshold', 500);currPoints.Location(:,2)=currPoints.Location(:,2)+cutoff;
    currPoints   = selectUniform(currPoints, numPoints, size(I));
    currFeatures = extractFeatures(I, currPoints);
    
    % Match features between the previous and current image.
    indexPairs = matchFeatures(prevFeatures, currFeatures, 'Unique', true, 'MaxRatio', 0.9);
end


function [relPose, inlierIdx] = helperEstimateRelativePose(matchedPoints1, matchedPoints2, intrinsics)

    if ~isnumeric(matchedPoints1)
        matchedPoints1 = matchedPoints1.Location;
    end
    
    if ~isnumeric(matchedPoints2)
        matchedPoints2 = matchedPoints2.Location;
    end
    
    for i = 1:100
        % Estimate the essential matrix.    
        [E, inlierIdx] = estimateEssentialMatrix(matchedPoints1, matchedPoints2,...
            intrinsics);
    
        % Make sure we get enough inliers
        if sum(inlierIdx) / numel(inlierIdx) < .3
            continue;
        end
        
        % Get the epipolar inliers.
        inlierPoints1 = matchedPoints1(inlierIdx, :);
        inlierPoints2 = matchedPoints2(inlierIdx, :);    
        
        % Compute the camera pose from the fundamental matrix. Use half of the
        % points to reduce computation.
        [relPose, validPointFraction] = ...
            estrelpose(E, intrinsics, inlierPoints1(1:2:end, :),...
            inlierPoints2(1:2:end, :));
    
        % validPointFraction is the fraction of inlier points that project in
        % front of both cameras. If the this fraction is too small, then the
        % fundamental matrix is likely to be incorrect.
        if validPointFraction > .7
           return;
        end
    end
    
    % After 100 attempts validPointFraction is still too low.
    error('Unable to compute the Essential matrix');
    validPointFraction
end


function [vSet, scaleFactor] = helperNormalizeViewSet(vSet, groundTruth)

    camPoses = poses(vSet);
    
    % Move the first camera to the origin.
    locations = vertcat(camPoses.AbsolutePose.Translation);
    locations = locations - locations(1, :);
    
    locationsGT  = cat(1, groundTruth.Location{1:height(camPoses)});
    magnitudes   = sqrt(sum(locations.^2, 2));
    magnitudesGT = sqrt(sum(locationsGT.^2, 2));
    scaleFactor = median(magnitudesGT(2:end) ./ magnitudes(2:end));
    
    % Rotate the poses so that the first camera points along the Z-axis
    R = camPoses.AbsolutePose(1).R;
    for i = 1:height(camPoses)
        % Scale the locations
        camPoses.AbsolutePose(i).Translation = camPoses.AbsolutePose(i).Translation * scaleFactor;
        camPoses.AbsolutePose(i).R = R' *camPoses.AbsolutePose(i).R;
    end
    
    vSet = updateView(vSet, camPoses);
end
