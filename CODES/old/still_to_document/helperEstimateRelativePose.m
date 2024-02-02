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
        estrelpose(E, intrinsics, inlierPoints1,...
        inlierPoints2);

    % validPointFraction is the fraction of inlier points that project in
    % front of both cameras. If the this fraction is too small, then the
    % fundamental matrix is likely to be incorrect.
    if validPointFraction > .7
        return;
    end
end

% After 100 attempts validPointFraction is still too low.
error('Unable to compute the Essential matrix');

end
