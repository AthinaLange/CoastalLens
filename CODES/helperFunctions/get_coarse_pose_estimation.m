function [R, answer] = get_coarse_pose_estimation(images, intrinsics, cutoff)
% GET COARSE POSE ESTIMATION - ASSUMING LITTLE AZIMUTHAL ROTATION
%
% within region of interest (bottom cutoff %) detect SURF features
% extract features in first frame
% for all subsequent images:
%   - detect SURF features
%   - find matching features between current frame and first frame
%   - estimate 2D image transformation between matching features
% return: 2D transformation for every frame, and recommendation for 2D or 3D transformation
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Nov 2023
%%

viewId = 1
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics);


% Detect features.
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 500;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features.
prevFeatures = extractFeatures(prevI, prevPoints);

ogI = prevI;
ogPoints = prevPoints;
ogFeatures = prevFeatures;

% Remaining Frames
% DO FOR ALL IMAGES WRT OG FRAME
for viewId = 2:length(images.Files)
    viewId

    % Read and display the next image
    Irgb = readimage(images, (viewId));

    % Convert to gray scale and undistort.
    I = undistortImage(im2gray(Irgb), intrinsics);

    % WRT OG IMAGE
    [currPoints, ~, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, cutoff, numPoints, 'On');

    % Eliminate outliers from feature matches.
    %[rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    [tform, ~] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    R.MinuteRate_OGFrame(viewId) = tform;

end % for viewId =1:length(images.Files)


% Check what rotation looks like
figure(1);clf
plot([0:0.5:0.5*(length(R.MinuteRate_OGFrame)-1)], [R.MinuteRate_OGFrame.RotationAngle], '.-','LineWidth',3, 'MarkerSize', 30)
xlabel('Minutes (frame every 30sec)')
ylabel('Image 2D Rotation Angle')
yline(0, 'LineWidth', 2, 'Color', 'k')
yline(5, 'LineStyle', '--', 'LineWidth', 1, 'Color', 'k')
yline(-5, 'LineStyle', '--', 'LineWidth', 1, 'Color', 'k')
set(gca, 'FontSize', 16)
title({'Coarse Pose Estimation (relative to 1st frame)', 'Recommended no larger than 5deg'})


if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5)
    disp('SMALL AZIMUTHAL ROTATION')
    answer = '2D'
else
    disp('LARGE AZIMUTHAL ROTATION')
    answer = questdlg('Do full 3D transformation? Or only 2D rotation while azimuthal change small (will cutoff when > 5deg)?', '3D or 2D transformation?', '2D', '3D', '2D');
end % if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5)




end
%%
function [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints, ~)
% Detect and extract features from the current image.
currPoints   = detectSURFFeatures(I(cutoff:end,:), 'MetricThreshold', 500);currPoints.Location(:,2)=currPoints.Location(:,2)+cutoff;
if contains('UniformTag', 'On')
    currPoints   = selectUniform(currPoints, numPoints, size(I));
end
currFeatures = extractFeatures(I, currPoints);

% Match features between the previous and current image.
indexPairs = matchFeatures(prevFeatures, currFeatures, 'Unique', true, 'MaxRatio', 0.9);
end

function [tform, inlierIdx] = helperEstimateRotation(matchedPoints1, matchedPoints2)

if ~isnumeric(matchedPoints1)
    matchedPoints1 = matchedPoints1.Location;
end

if ~isnumeric(matchedPoints2)
    matchedPoints2 = matchedPoints2.Location;
end


[tform, inlierIdx] = estgeotform2d(matchedPoints2, matchedPoints1,'similarity');


end

