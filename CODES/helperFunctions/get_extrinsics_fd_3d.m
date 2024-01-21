function [R] = get_extrinsics_fd_3d(odir, oname, images, worldPose, intrinsics, R, t)
% get camera extrinsics using feature detection
%% Syntax
%
%
%% Description
%
%
%
%%
  % First Frame
                viewId = 1;
                prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics);

                % Detect features.
                prevPoints = detectSURFFeatures(prevI(R.cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+R.cutoff;
                numPoints = 500;
                prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

                % Extract features.
                prevFeatures = extractFeatures(prevI, prevPoints);

                ogI = prevI;
                ogPoints = prevPoints;
                ogFeatures = prevFeatures;

                % Subsequent Frames
                if contains(R.rot_answer, '2D') | worldPose.Translation == [0 0 0] % do 2D rotation
                    for viewId = 2:length(images.Files)
                        % Read and display the next image
                        Irgb = readimage(images, (viewId));

                        % Convert to gray scale and undistort.
                        I = undistortImage(im2gray(Irgb), intrinsics);

                        % WRT OG IMAGE
                        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, R.cutoff, numPoints, 'On');

                        % Eliminate outliers from feature matches.
                        [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));

                        if abs(rotation.RotationAngle) > 5
                            images.Files(viewId:end)=[];
                            break
                        end
                        R.FullRate_OGFrame(viewId) = rotation;
                        if rem(viewId, 30*extract_Hz(hh)) == 0
                            disp(viewId)
                            figure(200); clf; I2=imshowpair(undistortImage(readimage(images, 1), intrinsics), ...
                                imwarp(undistortImage(readimage(images, viewId), intrinsics), R.FullRate_OGFrame(viewId), OutputView=imref2d(size(readimage(images, viewId-1)))));
                            title(sprintf('Time = %.1f min', viewId/extract_Hz(hh)/60))
                            saveas(gca, sprintf('warped_images_%iHz/warped_%isec.jpg', extract_Hz(hh), viewId/extract_Hz(hh)))
                        end
                    end %for viewId = 2:length(images.Files)

                elseif contains(R.rot_answer, '3D') & worldPose.Translation ~= [0 0 0] % do 3D transformation
                    R.FullRate_Adjusted = worldPose;
                    for viewId = 2:length(images.Files)

                        % Read and display the next image
                        Irgb = readimage(images, (viewId));

                        % Convert to gray scale and undistort.
                        I = undistortImage(im2gray(Irgb), intrinsics);

                        % Detect Features
                        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, R.cutoff, numPoints, 'On');

                        try
                            [relPose, inlierIdx] = helperEstimateRelativePose(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)), intrinsics);
                        catch
                            % Get Essential Matrix
                            [E, inlierIdx] = estimateEssentialMatrix(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)), intrinsics);

                            % Get the epipolar inliers.
                            indexPairs = indexPairs(inlierIdx,:);

                            % Compute the camera pose from the fundamental matrix.
                            [relPose, validPointFraction] = estrelpose(E, intrinsics, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
                        end

                        % if multiple relative Poses are obtained
                        if length(relPose) ~= 1
                            % Do first check if image projection is very wrong - origin of grid should be within image frame
                            [UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(Products(1).lat, Products(1).lon);
                            coords = horzcat(UTMEasting, UTMNorthing, 5.4);
                            for rr = length(relPose):-1:1
                                aa = worldPose.A *  relPose(rr).A;
                                absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                                iP = world2img(coords, pose2extr(absPose), intrinsics);
                                % if origin of grid is projected outside of image -> problem
                                if any(any(iP(:)> max(intrinsics.ImageSize))) || any(any(iP(:)< 0))
                                    relPose(rr) = [];
                                end % if any(any(iP(:)> max(intrinsics.ImageSize))) || any(any(iP(:)< 0))
                            end % for rr = length(relPose):-1:1

                            if length(relPose) ~= 1
                                % find projection point that is closest Euclidian distance to previous frame origin point
                                previP = world2img(coords, pose2extr(R.FullRate_Adjusted(viewId-1)), intrinsics);
                                clear dist
                                for rr = 1:length(relPose)
                                    aa = worldPose.A *  relPose(rr).A;
                                    absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                                    iP = world2img(coords, pose2extr(absPose), intrinsics);
                                    dist(rr) = pdist2(previP, iP);
                                end % for rr = 1:length(relPose)
                                [~,i]=min(dist);
                                relPose = relPose(i);
                            end % if length(relPose) ~= 1
                        end  % if length(relPose) ~= 1

                        R.FullRate_OGFrame(viewId) = relPose;
                        aa = worldPose.A *  relPose.A;
                        absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                        R.FullRate_Adjusted(viewId) = absPose;

                        if rem(viewId, 30*extract_Hz(hh)) == 0
                            disp(viewId)
                            figure(200);clf
                            showMatchedFeatures(ogI,I, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
                            title(sprintf('Time = %.1f min', viewId/extract_Hz(hh)/60))
                            saveas(gca, sprintf('warped_images_%iHz/matching_%isec.jpg', extract_Hz(hh), viewId/extract_Hz(hh)))
                        end
                    end % for viewId = 2:length(images.Files)
                end % if contains(R.rot_answer, '2D')

                

                %  Save File
                save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_' char(string(extract_Hz(hh))) 'Hz' ]),'R', 'intrinsics', 't')



end


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

function [tform, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(matchedPoints1, matchedPoints2)

if ~isnumeric(matchedPoints1)
    matchedPoints1 = matchedPoints1.Location;
end

if ~isnumeric(matchedPoints2)
    matchedPoints2 = matchedPoints2.Location;
end


[tform, inlierIdx] = estgeotform2d(matchedPoints2, matchedPoints1,'rigid');


invTform = invert(tform);
Ainv = invTform.A;

ss = Ainv(1,2);
sc = Ainv(1,1);
scaleRecovered = hypot(ss,sc);
%disp(['Recovered scale: ', num2str(scaleRecovered)])

% Recover the rotation in which a positive value represents a rotation in
% the clockwise direction.
thetaRecovered = atan2d(-ss,sc);
%disp(['Recovered theta: ', num2str(thetaRecovered)])

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

% Callback function for the pause button

