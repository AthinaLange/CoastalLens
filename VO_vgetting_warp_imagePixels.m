%% MONOCULAR VISUAL ODOMETRY
clear all
close all

 hh=1
extract_Hz = 10
%% Torrey
imageDirectory = '/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/images_10Hz/'
images = imageDatastore(imageDirectory)

load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IOEOInitial.mat', 'extrinsics', 'intrinsics')
intrinsicsCIRN = intrinsics;
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IO.mat', 'cameraParams')
intrinsics = cameraParams.Intrinsics;

%% Blacks
imageDirectory = '/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/images_10Hz/'
images = imageDatastore(imageDirectory); 

load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/Processed_data/20230208_Blacks_01_IOEOInitial.mat', 'extrinsics', 'intrinsics')
intrinsicsCIRN = intrinsics;
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/Processed_data/20230208_Blacks_01_IO.mat', 'cameraParams')
intrinsics = cameraParams.Intrinsics;

%% ====================================================================
%                       COARSE POSE ESTIMATION - ASSUMING NO TRANSLATION
% ======================================================================
%%
%% 1st Frame
close all
clear R
images = imageDatastore(imageDirectory);
images.Files = images.Files(1:extract_Hz(hh)*30:end)

viewId = 1
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 

cutoff = round(size(prevI,1)*(3/4));

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
for viewId =1:length(images.Files)
    viewId
   
    % Read and display the next image
    Irgb = readimage(images, (viewId));
    
    % Convert to gray scale and undistort.
     I = undistortImage(im2gray(Irgb), intrinsics);
    
    % WRT OG IMAGE
    [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, cutoff, numPoints, 'On');

    % Eliminate outliers from feature matches.
    [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    R.MinuteRate_OGFrame(viewId) = rotation;

end

% Check what rotation looks like
 
if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5)
    disp('SMALL AZIMUTHAL ROTATION')
else
    disp('LARGE AZIMUTHAL ROTATION')
end
figure
plot([R.MinuteRate_OGFrame.RotationAngle])
%% ====================================================================
%                                                   EVERY FRAME
%           - SMALL CHANGE: in reference to initial image to reduce accumulating drift errors
%           - LARGE CHANGE: in reference to previous image - correct for accumulated drift later
% ======================================================================
close all

images = imageDatastore(imageDirectory);

viewId = 1
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 

cutoff = round(size(prevI,1)*(1/2));

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 500;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

ogI = prevI;
ogPoints = prevPoints;
ogFeatures = prevFeatures;
tic
if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5) % Small Azimuthal Rotation
   
    for viewId = 2:length(images.Files)
        if rem(viewId,100)==0
            viewId
            toc
        end
        % Read and display the next image
        Irgb = readimage(images, (viewId));
        
        % Convert to gray scale and undistort.
         I = undistortImage(im2gray(Irgb), intrinsics);
        
        % WRT OG IMAGE
        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, cutoff, numPoints, 'On');
    
        % Eliminate outliers from feature matches.
        [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
        R.FullRate_OGFrame(viewId) = rotation;
    end

else % Large Azimuthal Rotation
   
    R.FullRate_Adjusted = rigidtform2d;

    for viewId = 2:length(images.Files)
        if rem(viewId,100)==0
            viewId
            toc
        end
        % Read and display the next image
        Irgb = readimage(images, (viewId));
        
        % Convert to gray scale and undistort.
         I = undistortImage(im2gray(Irgb), intrinsics);
        
        % WRT prev IMAGE
        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints, 'On');
    
        % Eliminate outliers from feature matches.
        [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(prevPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
        R.FullRate_prevFrame(viewId) = rotation;
        R.FullRate_Adjusted(viewId).A = R.FullRate_Adjusted(viewId-1).A * R.FullRate_prevFrame(viewId).A;
        
        prevI = I;
        prevPoints = currPoints;
        prevFeatures = currFeatures;

    end
end


%% ====================================================================
%                                                   GET PIXELS
% ======================================================================

%% GET PIXELS

% VISUALIZE CHANGE
% for viewId = 2:length(images.Files)
%    % figure(100); clf; I1= imshowpair(readimage(images, viewId-1),readimage(images, viewId));
%     % figure(200); clf; I2=imshowpair(readimage(images, 1), ...
%     %     imwarp(readimage(images, viewId), R_fullAdjusted(viewId), OutputView=imref2d(size(readimage(images, viewId-1)))));
%     % figure(1);clf;
%     % imshowpair(I1.CData, I2.CData, 'montage')
%     % title('Raw                                                Corrected')
%     % pause(0.5)
% end

for viewId = 1:length(images.Files)
    for pp = 1:2
        I = undistortImage(readimage(images, viewId), intrinsics);
        if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5) % Small Azimuthal Rotation
        correction = R.FullRate_OGFrame(viewId);
        else
        correction = R.FullRate_Adjusted(viewId); 
        end
        I_corrected= imwarp(I, correction, OutputView=imref2d(size(I)));
        [IrIndv] = getPixels(Products, pp, extrinsics, intrinsicsCIRN, I_corrected);
        if pp == 1
            Ir_grid(viewId,:,:,:) = IrIndv;
        elseif pp == 2
            Ir_time(viewId,:,:) = IrIndv;
        end
    end
end   


%%

for ii = 1:1171
    aa(ii)=R.FullRate_OGFrame(ii).RotationAngle;
end
clf;
subplot(211)
plot(aa)
ylabel('Rotation Angle')
set(gca, 'FontSize', 30)
yline(0)
xlim([1 1171])
title('Torrey 20211026 01 2D rotation')
subplot(212);
image(permute(Ir_time,[2 1 3]))
set(gca, 'FontSize', 30)
xlim([1 1171])
xlabel('Frames')
ylabel('Cross-shore Distance')
yticklabels({'400', '300', '200', '100', '0'})





%% FUNCTIONS

function [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints, UniformTag)
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
            estrelpose(E, intrinsics, inlierPoints1(1:2:end, :),...
            inlierPoints2(1:2:end, :));
    
        % validPointFraction is the fraction of inlier points that project in
        % front of both cameras. If the this fraction is too small, then the
        % fundamental matrix is likely to be incorrect.
        if validPointFraction > .7
          % return;
        end
    end
    relPose
    % After 100 attempts validPointFraction is still too low.
    error('Unable to compute the Essential matrix');
  
end

function[IrIndv] = getPixels(Products, pp, extrinsics, intrinsicsCIRN, I)

    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    localExtrinsics = localTransformExtrinsics([x2 y2], 270-Products(pp).angle, 1, extrinsics);
    

    if contains(Products(pp).type, 'Grid')
        if Products(pp).xlim(1) < 0; Products(pp).xlim(1) = -Products(pp).xlim(1); end
        ixlim = x2 - Products(pp).xlim;
        
        if Products(pp).ylim(1) > 0; Products(pp).ylim(1) = -Products(pp).ylim(1); end
        if Products(pp).ylim(2) < 0; Products(pp).ylim(2) = -Products(pp).ylim(2); end
        iylim = y2 + Products(pp).ylim;
        
        [iX, iY]=meshgrid(ixlim(1):Products(pp).dx:ixlim(2),iylim(1):Products(pp).dy:iylim(2));
        
        % DEM stuff
        if isempty(Products(pp).z); iz=0; else; iz = Products(pp).z; end
        iZ=iX*0+iz;
        
        X=iX; Y=iY; Z=iZ; 
        [localX, localY]=localTransformEquiGrid([x2 y2], 270-Products(pp).angle,1,iX,iY); 
        localZ=localX.*0+iz;  X = localX;
           
        xyz = [localX(:) localY(:) localZ(:)];
    elseif contains(Products(pp).type, 'xTransect')
            if Products(pp).xlim(1) < 0; Products(pp).xlim(1) = -Products(pp).xlim(1); end
            ixlim = x2 - Products(pp).xlim;
            iy = y2 + Products(pp).y;
        
            X = [ixlim(1):Products(pp).dx:ixlim(2)]';
            Y = X.*0+iy;
            if isempty(Products(pp).z); iz=0; else; iz = Products(pp).z; end
            Z = X.*0 + iz;
            [ Xout Yout]= localTransformPoints([x2 y2], 270-Products(pp).angle,1,X,Y);
            xyz = cat(2,Xout(:), Yout(:), Z(:));
    end
    
    [P, K, R, IC] = intrinsicsExtrinsics2P(intrinsicsCIRN, localExtrinsics);
    
    % Find the Undistorted UV Coordinates atributed to each xyz point.
    UV = P*[xyz'; ones(1,size(xyz,1))];
    UV = UV./repmat(UV(3,:),3,1);  % Make Homogenenous
    
    % So the camera image we are going to pull pixel values from is distorted.
    % Our P matrix transformation assumes no distortion. We have to correct for
    % this. So we distort our undistorted UV coordinates to pull the correct
    % pixel values from the distorted image. Flag highlights invalid points
    % (=0) using intrinsic criteria.
    [~,~,flag] = distortUV(UV(1,:),UV(2,:),intrinsicsCIRN);
    
    % Find Negative Zc Camera Coordinates. Adds invalid point to flag (=0).
    xyzC = R*IC*[xyz'; ones(1,size(xyz,1))];
    bind= find(xyzC (3,:)<=0);
    flag(bind)=0;
    
    % Make into a singular matrix for use in the non-linear solver
    UVd = [UV(1,:)' UV(2,:)'];
    %UVd = [Ud; Vd];
    
    
    %UVd = reshape(UVd,[],2);
    s=size(X);
    Ud=(reshape(UVd(:,1),s(1),s(2)));
    Vd=(reshape(UVd(:,2),s(1),s(2)));
    
    % Round UVd coordinates so it cooresponds to matrix indicies in image I
    Ud=round(Ud);
    Vd=round(Vd);
    
    % Utalize Flag to remove invalid points. See xyzDistUV and distortUV to see
    % what is considered an invalid point.
    Ud(find(flag==0))=nan;
    Vd(find(flag==0))=nan;
    
    % dimension for rgb values.
    ir=nan(s(1),s(2),3);
    
    % Pull rgb pixel intensities for each point in XYZ
    for kk=1:s(1)
        for j=1:s(2)
            % Make sure not a bad coordinate
            if isnan(Ud(kk,j))==0 & isnan(Vd(kk,j))==0
                % Note how Matlab organizes images, V coordinate corresponds to
                % rows, U to columns. V is 1 at top of matrix, and grows as it
                % goes down. U is 1 at left side of matrix and grows from left
                % to right.
                ir(kk,j,:)=I(Vd(kk,j),Ud(kk,j),:);
            end
        end
    end
    
    % Save Rectifications from Each Camera into A Matrix
    IrIndv=uint8(ir);












end
