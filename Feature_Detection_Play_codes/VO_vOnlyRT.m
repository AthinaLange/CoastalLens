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
%  - Not making any assumptions on movement - so movement in
%        reference to previous frame.
% ======================================================================
%%
images.Files = images.Files(1:extract_Hz(hh)*60:end)

% Create an empty imageviewset object to manage the data associated with each view.
%vSet = imageviewset;
viewId = 1
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 

%cutoff = round(size(prevI,1)*(3/4)); 
cutoff = round(size(prevI,1)*(1/2));

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 500;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

% Add the first view.
%vSet = addView(vSet, viewId, Points=prevPoints, Features=prevFeatures);

close all 

% DO FOR ALL IMAGES
for viewId = 2:length(images.Files)
    viewId
    % Read and display the next image
    Irgb = readimage(images, (viewId));
    
    % Convert to gray scale and undistort.
     I = undistortImage(im2gray(Irgb), intrinsics);
    
    % Match points between the previous and the current image.
    [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints, 'On');

    % Eliminate outliers from feature matches.
    [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(prevPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    R.MinuteRate(viewId) = rotation;
    indexPairs = indexPairs(inlierIdx, :);

    %vSet = addView(vSet, viewId, Points=currPoints, Features=currFeatures);
     
    % Store the point matches between the previous and the current views.
    %vSet = addConnection(vSet, viewId-1, viewId, Matches=indexPairs);
    showMatchedFeatures(prevI, I, prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
    title(['ViewId = ' char(string(viewId))])
    pause(0.5)
 
    prevI = I;
    prevPoints = currPoints;
    prevFeatures = currFeatures;
end


% VISUALIZE CHANGE
R.MinuteAdjusted = R.MinuteRate;
for viewId = 2:length(images.Files)
    R.MinuteAdjusted(viewId).A = R.MinuteAdjusted(viewId-1).A *  R.MinuteAdjusted(viewId).A;
    figure(100); clf; I1= imshowpair(readimage(images, viewId-1),readimage(images, viewId));
    figure(200); clf; I2=imshowpair(readimage(images, 1), ...
        imwarp(readimage(images, viewId), R.MinuteAdjusted(viewId), OutputView=imref2d(size(readimage(images, viewId-1)))));
    figure(viewId)
    imshowpair(I1.CData, I2.CData, 'montage')
    title('Raw                                                Corrected')
end


% CHECK IF CHANGE IS MOSTLY CORRECTED FOR
%vSet_corrected = imageviewset;
viewId = 1;
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 

cutoff = round(size(prevI,1)*(3/4)); 

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 500;
%prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

% Add the first view.
%vSet_corrected = addView(vSet_corrected, viewId, Points=prevPoints, Features=prevFeatures);

figure
for viewId = 2:length(images.Files)
    viewId
    % Read and display the next image
    Irgb = readimage(images, (viewId));
    
    % Convert to gray scale and undistort.
     I = undistortImage(im2gray(Irgb), intrinsics);

     % Apply initial correction
     I = imwarp(I, R.MinuteAdjusted(viewId), OutputView=imref2d(size(I)));
   
    % Match points between the previous and the current image.
    [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints, 'Off');

    % Eliminate outliers from feature matches.
    [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(prevPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    R.MinuteCorrected(viewId) = rotation;
    indexPairs = indexPairs(inlierIdx, :);

    %vSet_corrected = addView(vSet_corrected, viewId, Points=currPoints, Features=currFeatures);
     
    % % Store the point matches between the previous and the current views.
    %vSet_corrected = addConnection(vSet_corrected, viewId-1, viewId, Matches=indexPairs);
    showMatchedFeatures(prevI, I, prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
    title(['ViewId = ' char(string(viewId))])
    pause(0.5)
   
    prevI = I;
    prevFeatures = currFeatures;
    prevPoints   = currPoints;  
   
end
%%
clf;
subplot(211)
plot([1:60*10:length(R.MinuteRate)*60*10],[R.MinuteRate.RotationAngle], 'LineWidth', 3)
hold on
plot([1:60*10:length(R.MinuteRate)*60*10],[R.MinuteCorrected.RotationAngle], 'LineWidth', 3)

yline(0)
legend('Every min frames', 'Corrected every min frames', 'Location', 'best')
title('Changes between frames')
ylabel('Deg')

set(gca, 'FontSize', 20)

subplot(212)
plot([1:60*10:length(R.MinuteRate)*60*10],[R.MinuteAdjusted.RotationAngle], 'LineWidth', 3)
hold on
title('Total change')
ylabel('Deg')
xlabel('Frame')
yline(0)
legend('Every min frames', 'Location', 'best')
set(gca, 'FontSize', 20)

% TO CHECK IF TRANSLATION = 0 ASSUMPTION APPROPRIATE:
% XXX TBD SHOULD THIS BE ADJUSTED RATE OR CORRECTED RATE?
if all(abs([R.MinuteCorrected.RotationAngle]) < 0.1)
    disp('ROTATION ONLY')
else
    disp('NEED TRANSLATION')
end


%% ====================================================================
%                                                   ROTATION ONLY
%           - in reference to initial image to reduce accumulating drift errors
% ======================================================================
%% 1st Frame
images = imageDatastore(imageDirectory);
images.Files = images.Files(1:3000);

% Create an empty imageviewset object to manage the data associated with each view.
%vSet = imageviewset;
viewId = 1
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 

cutoff = round(size(prevI,1)*(1/2));

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 500;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

% Add the first view.
viewId = 1;
%vSet = addView(vSet, viewId, Points=prevPoints, Features=prevFeatures);

close all 
ogI = prevI;
ogPoints = prevPoints;
ogFeatures = prevFeatures;
R.FullAdjusted_prevFrame=rigidtform2d;
%% Remaining Frames
% DO FOR ALL IMAGES - combine previous Frame with bundle adjustment every
% 30sec with comparison to original frame
for viewId =2:length(images.Files)
    %viewId
    if rem(viewId,100)==0%rem(viewId,extract_Hz(hh)*60)==0
        viewId
        toc
    end
        % Read and display the next image
    Irgb = readimage(images, (viewId));
    
    % Convert to gray scale and undistort.
     I = undistortImage(im2gray(Irgb), intrinsics);
    
    %% WRT PREV IMAGE
    %Match points between the previous and the current image.
    [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints, 'On');

    % Eliminate outliers from feature matches.
    [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(prevPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    R.FullRate_prevFrame(viewId) = rotation;
    aa = R.FullAdjusted_prevFrame(viewId-1).A *  R.FullRate_prevFrame(viewId).A;
    R.FullAdjusted_prevFrame(viewId) = rigidtform2d(aa(1:2,1:2), aa(1:2,3));

    indexPairs = indexPairs(inlierIdx, :);
    % Store the point matches between the previous and the current views.
    %vSet = addView(vSet, viewId, absPose=R.FullAdjusted_prevFrame(viewId) , Points=currPoints, Features=currFeatures);
   % vSet = addConnection(vSet, viewId-1, viewId, Matches=indexPairs);
     if rem(viewId,100)==0%rem(viewId,extract_Hz(hh)*60)==0
        figure
       showMatchedFeatures(prevI, I, prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
        title(['ViewId = ' char(string(viewId)) ', prevFrame'])
        tic
    end
        
    % 
    % pause(0.5)

    prevI=I;
    prevPoints = currPoints;
    prevFeatures = currFeatures;

    %% WRT OG IMAGE
    if rem(viewId,100)==0%rem(viewId,extract_Hz(hh)*60)==0
        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, cutoff, numPoints, 'On');
    
        % Eliminate outliers from feature matches.
        [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
        R.FullRate_OGFrame(viewId) = rotation;

        %KEYFRAME ADJUSTMENT

        % TBD
    
       %  figure
       %  indexPairs = indexPairs(inlierIdx, :);
       % showMatchedFeatures(ogI, I, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
       % title(['ViewId = ' char(string(viewId)) ', ogFrame'])
    end
end


% VISUALIZE CHANGE

for viewId = 2:length(images.Files)
   figure(100); clf; I1= imshowpair(readimage(images, viewId-1),readimage(images, viewId));
    figure(200); clf; I2=imshowpair(readimage(images, 1), ...
        imwarp(readimage(images, viewId), R_fullAdjusted(viewId), OutputView=imref2d(size(readimage(images, viewId-1)))));
    figure(1);clf;
    imshowpair(I1.CData, I2.CData, 'montage')
    title('Raw                                                Corrected')
    pause(0.5)
end



%% PLOTS
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/colors.mat')
clf;
subplot(211)
%plot([1:60*10:length(R.MinuteRate)*60*10],[R.MinuteRate.RotationAngle], 'LineWidth', 3)
hold on
%plot([1:60*10:length(R.MinuteRate)*60*10],[R.MinuteCorrected.RotationAngle], 'LineWidth', 3)
plot([R.FullRate_prevFrame.RotationAngle], 'LineWidth', 3)
plot([100:100:100],[R.FullRate_OGFrame(100:100:100).RotationAngle], '.','Color', colors(4,:), 'LineWidth', 3, 'MarkerSize', 50)
yline(0)
legend('Every min frames', 'Corrected every min frames', 'Every frame', 'Every frame wrt OG', 'Location', 'best')
title('Changes between frames')
ylabel('Deg')

set(gca, 'FontSize', 20)
%xlim([0 10])
%ylim([-0.015 0.015])

subplot(212)
%plot([1:60*10:length(R.MinuteRate)*60*10],[R.MinuteAdjusted.RotationAngle], 'LineWidth', 3)
hold on
plot([R.FullAdjusted_prevFrame.RotationAngle], 'Color', colors(3,:), 'LineWidth', 3)
plot([100:100:100],[R.FullRate_OGFrame(100:100:100).RotationAngle], '.','Color', colors(4,:), 'LineWidth', 3, 'MarkerSize', 50)
title('Total change')
ylabel('Deg')
xlabel('Frame')
yline(0)
legend('Every min frames', 'Every frame', 'Every frame wrt OG', 'Location', 'best')
set(gca, 'FontSize', 20)
%xlim([0 10])
%ylim([-0.015 0.015])

load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/colors.mat')
clf;
subplot(211)
hold on
for ii = 1:100
    plot3(R.FullRate_prevFrame(ii).Translation(1), R.FullRate_prevFrame(ii).Translation(2),ii, '.', 'MarkerSize', 50, 'Color', colors(1,:))
end
    plot3(R.FullRate_OGFrame(100).Translation(1), R.FullRate_prevFrame(100).Translation(2),100, '.', 'MarkerSize', 100, 'Color', colors(2,:))

title('Changes between frames')

set(gca, 'FontSize', 20)
xlabel('x')
ylabel('y')
grid on

subplot(212)
hold on
for ii = 1:100
    plot3(R.FullAdjusted_prevFrame(ii).Translation(1), R.FullAdjusted_prevFrame(ii).Translation(2),ii, '.', 'MarkerSize', 50, 'Color', colors(1,:))
end
    plot3(R.FullRate_OGFrame(100).Translation(1), R.FullRate_prevFrame(100).Translation(2),100, '.', 'MarkerSize', 100, 'Color', colors(2,:))

title('Total Change')

set(gca, 'FontSize', 20)
xlabel('x')
ylabel('y')
grid on
%xlim([0 10])
%ylim([-0.015 0.015])

subplot(212)
%plot([1:60*10:length(R.MinuteRate)*60*10],[R.MinuteAdjusted.RotationAngle], 'LineWidth', 3)
hold on
plot([R.FullAdjusted_prevFrame.RotationAngle], 'Color', colors(3,:), 'LineWidth', 3)
plot([100:100:100],[R.FullRate_OGFrame(100:100:100).RotationAngle], '.','Color', colors(4,:), 'LineWidth', 3, 'MarkerSize', 50)
title('Total change')
ylabel('Deg')
xlabel('Frame')
yline(0)
legend('Every min frames', 'Every frame', 'Every frame wrt OG', 'Location', 'best')
set(gca, 'FontSize', 20)
%xlim([0 10])
%ylim([-0.015 0.015])


%[iDark, iBright, iTimex] = makeARGUSproducts(images, R.FullAdjusted_prevFrame, intrinsics);
%[iDark, iBright, iTimex] = makeARGUSproducts(images, R.FullRate_OGFrame, intrinsics);
%% ====================================================================
%                                           TRANSLATION + ROTATION
% ======================================================================
% load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/pointhandles.mat')
% [UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(origin_grid(1), origin_grid(2))
% gcp_xyz(:,1) = gcp_xyz(:,1) - UTMEasting;
% gcp_xyz(:,2) = gcp_xyz(:,2) - UTMNorthing;

load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/Processed_data/20230208_Blacks_01_IO.mat', 'cameraParams')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/Processed_data/20230208_Blacks_01_IOEOInitial.mat', 'image_gcp')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/Processed_data/20230208_Blacks_01_IOEOInitial.mat', 'world_gcp')

%% 1st Frame
images = imageDatastore(imageDirectory);
images.Files = images.Files(1:3000);

% Create an empty imageviewset object to manage the data associated with each view.
vSet = imageviewset;
viewId = 1
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 

cutoff = round(size(prevI,1)*(1/2));
% Get initial camera pose
% odir='/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/'
% select_image_gcp
% select_target_gcp
% world_gcp = target_gcp;
%worldPose = estworldpose(image_gcp,world_gcp, cameraParams.Intrinsics);
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/worldPose.mat')

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 2000;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

% Add the first view.
viewId = 1;
vSet = addView(vSet, viewId, absPose=worldPose, Points=prevPoints, Features=prevFeatures);

close all 
ogI = prevI;
ogPoints = prevPoints; 
ogFeatures = prevFeatures;


%% Remaining Frames

for viewId =2:100%:length(images.Files)
    viewId
    if rem(viewId,100)==0%rem(viewId,extract_Hz(hh)*60)==0
        viewId
        toc
    end
    % Read and display the next image
    Irgb = readimage(images, (viewId));
    
    % Convert to gray scale and undistort.
    I = undistortImage(im2gray(Irgb), intrinsics);

    %Match points between the previous and the current image.
    [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, cutoff, numPoints, 'On');

    
 %    [relPose, inlierIdx] = helperEstimateRelativePose(ogPoints(indexPairs(:,1)),...
 %      currPoints(indexPairs(:, 2)), intrinsics);

      [E, inlierIdx] = estimateEssentialMatrix(ogPoints(indexPairs(:,1)),...
       currPoints(indexPairs(:, 2)), intrinsics);
    
        
        % Get the epipolar inliers.
        indexPairs = indexPairs(inlierIdx,:);
        
        % Compute the camera pose from the fundamental matrix. Use half of the
        % points to reduce computation.
        [relPose, validPointFraction] = estrelpose(E, intrinsics, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));

   length(relPose)
     if length(relPose) == 1

        R.relPose(viewId) = relPose;
        aa = worldPose.A *  relPose.A;
        absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
         vSet = addView(vSet, viewId, absPose=absPose, Points=currPoints);

        % % Store the point matches between the previous and the current views.
        vSet = addConnection(vSet, 1, viewId, Matches=indexPairs);

    elseif length(relPose) == 2
        R.relPose(viewId) = relPose(1);
    
        aa = worldPose.A *  relPose(1).A;
        absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
        vSet = addView(vSet, viewId, absPose=absPose, Points=currPoints);
        vSet = addConnection(vSet, 1, viewId, Matches=indexPairs);

        R.relPose_alt(viewId) = relPose(2);


    elseif length(relPose) == 4


        for ii = 1:length(relPose)
            imagePointsOG(ii,:,:) = world2img(world_gcp,pose2extr(worldPose),intrinsics);
            [imagePoints(ii,:,1),imagePoints(ii,:,2)] = transformPointsForward(relPose(ii),imagePointsOG(ii,:,1), imagePointsOG(ii,:,2), ones(size(imagePointsOG(ii,:,1),1), size(imagePointsOG(ii,:,1),2)));
        end
        id = unique([find(any(squeeze(imagePoints(:,:,1)) < 0,2)) find(any(squeeze(imagePoints(:,:,1)) > size(I,2),2)) ...
        find(any(squeeze(imagePoints(:,:,2)) < 0,2)) find(any(squeeze(imagePoints(:,:,2)) > size(I,1),2))]);

        relPose(id)=[];
        R.relPose(viewId) = relPose(1);

        aa = worldPose.A *  relPose(1).A;
        absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
        vSet = addView(vSet, viewId, absPose=absPose, Points=currPoints);
        vSet = addConnection(vSet, 1, viewId, Matches=indexPairs);

        R.relPose_alt(viewId) = relPose(2);

     end
    
   
    prevI = I;
    prevPoints = currPoints;
    prevFeatures = currFeatures;
end
    %%

viewId=1000
 Irgb = readimage(images, (viewId));
    
    % Convert to gray scale and undistort.
    I = undistortImage(im2gray(Irgb), intrinsics);

    %Match points between the previous and the current image.
    [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, cutoff, numPoints, 'On');

    
 %    [relPose, inlierIdx] = helperEstimateRelativePose(ogPoints(indexPairs(:,1)),...
 %      currPoints(indexPairs(:, 2)), intrinsics);

       [E, inlierIdx] = estimateEssentialMatrix(ogPoints(indexPairs(:,1)),...
       currPoints(indexPairs(:, 2)), intrinsics);
    
        
        % Get the epipolar inliers.
        indexPairs = indexPairs(inlierIdx,:);
        
        % Compute the camera pose from the fundamental matrix. Use half of the
        % points to reduce computation.
        [relPose, validPointFraction] = ...
            estrelpose(E, intrinsics, ogPoints(indexPairs(:,1)),...
            currPoints(indexPairs(:, 2)));
    

    %%
clear imagePoints*
    for ii = 1:length(relPose)
       % aa = relPose(ii).A;%worldPose.A *  relPose(ii).A;
    %    absPose(ii) = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
        imagePointsOG(ii,:,:) = world2img(world_gcp,pose2extr(worldPose),intrinsics);
       [imagePoints(ii,:,1),imagePoints(ii,:,2)] = transformPointsForward(relPose(ii),imagePointsOG(ii,:,1), imagePointsOG(ii,:,2), ones(size(imagePointsOG(ii,:,1),1), size(imagePointsOG(ii,:,1),2)))
    end
    id = unique([find(any(squeeze(imagePoints(:,:,1)) < 0,2)) find(any(squeeze(imagePoints(:,:,1)) > size(I,2),2)) ...
        find(any(squeeze(imagePoints(:,:,2)) < 0,2)) find(any(squeeze(imagePoints(:,:,2)) > size(I,1),2))])

    relPose(id)=[];
%%
figure(1);clf
image(I)
hold on
for ii = 1:length(relPose)
plot(imagePoints(ii,:,1), imagePoints(ii,:,2), '.','Color', colors(ii+2,:), 'MarkerSize', 30)
end
legend( '1', '2', '3', '4')

    %%
  
    %% WRT OG IMAGE
    if rem(viewId,100)==0%rem(viewId,extract_Hz(hh)*60)==0
        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, cutoff, numPoints, 'On');
    
        % Eliminate outliers from feature matches.
        [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
        R.FullRate_OGFrame(viewId) = rotation;

        %KEYFRAME ADJUSTMENT

        % TBD
    
       %  figure
       %  indexPairs = indexPairs(inlierIdx, :);
       % showMatchedFeatures(ogI, I, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
       % title(['ViewId = ' char(string(viewId)) ', ogFrame'])
    end


% VISUALIZE CHANGE
%%
for viewId = 2%2:length(images.Files)
   figure(100); clf; I1= imshowpair(undistortImage(rgb2gray(readimage(images, 1)), intrinsics),undistortImage(rgb2gray(readimage(images, viewId)), intrinsics));
    figure(200); clf; I2=imshowpair(undistortImage(rgb2gray(readimage(images, 2)), intrinsics), ...
        imwarp([undistortImage(rgb2gray(readimage(images, viewId)), intrinsics),zeros(2160,3840)], R.relPose(viewId)));
    %figure(1);clf;
   % imshowpair(I1.CData, I2.CData, 'montage')
   % title('Raw                                                Corrected')
    pause(0.5)
end




%% 1. CAPTURE IMAGES


load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/CPG_data/origin_Torrey.mat')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/colors.mat')

load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IO.mat', 'cameraParams')
intrinsics = cameraParams.Intrinsics;
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/pointhandles.mat')
[UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(origin_grid(1), origin_grid(2))
gcp_xyz(:,1) = gcp_xyz(:,1) - UTMEasting;
gcp_xyz(:,2) = gcp_xyz(:,2) - UTMNorthing;


% Create an empty imageviewset object to manage the data associated with each view.
vSet = imageviewset;

% Read and display the first image.
I1 = readimage(images, 1);
I2 = readimage(images, 100);


prevI = undistortImage(im2gray(I1), intrinsics); 
currI = undistortImage(im2gray(I2), intrinsics); 
%% 2. GET 1st image

cutoff = round(size(I1,1)*(3/4)); 

% Get initial camera pose
worldPose = estworldpose(squeeze(pointhandles(1,:,:)),gcp_xyz, cameraParams.Intrinsics);

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 500;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

% CAN INCLUDE HORIZON HERE
% Horizon.R=7/6*6378*1000; % World Radius in Meters
% Horizon.h=extrinsics(3);
% Horizon.d=sqrt(2*Horizon.R*Horizon.h+Horizon.h^2);
% Horizon.deg=0;
% Horizon.eutm=extrinsics(1)+cos(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
% Horizon.nutm=extrinsics(2)+sin(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
% Horizon.zh=0; % should be tide %% XXX TBD
% [UVd,flag] = xyz2DistUV(intrinsicsCIRN,extrinsics,[Horizon.eutm' Horizon.nutm' Horizon.zh']);
% sky = round([UVd(1) UVd(2)/2]);
% water = round([UVd(1) UVd(2)+UVd(2)/2]);
% figure(1);clf
% imshow(prevI)
% hold on
% drawpoint('Position', sky, 'Label', ['Sky Point']);
% drawpoint('Position', water, 'Label', ['Water Point']);
% [horizon_line(viewId,:)] = get_horizon(prevI, sky, water);
% clear HorizonPts
% x = [10 round(size(prevI,2)/2) size(prevI,2)-10];
% HorizonPts(viewId,:) = horizon_line(viewId,1)*x + horizon_line(viewId,2);
% perc_20 = min(HorizonPts(viewId,:))/5;
% sky =  round([mean(x) min(HorizonPts(viewId,:)) - perc_20]);
% water = round([mean(x) max(HorizonPts(viewId,:)) + perc_20]);
% 
% prevPoints = vertcat(prevPoints, SURFPoints([x; HorizonPts(viewId,:)]', Metric=selectStrongest(prevPoints,1).Metric));

% Add the first view. Place the camera associated with the first view
% at the origin, oriented along the Z-axis.
viewId = 1;

vSet = addView(vSet, viewId, worldPose, Points=prevPoints, Features=prevFeatures);
figure(1);clf
imshow(prevI)
hold on
plot(prevPoints)

%% 3. FEATURE DETECTION

viewId=2
[currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, currI, cutoff, numPoints);

% Eliminate outliers from feature matches. - using 8-point relative pose estimation algorithm
[relPose, inlierIdx] = helperEstimateRelativePose(prevPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)), intrinsics);
    indexPairs = indexPairs(inlierIdx, :);

showMatchedFeatures(I1, I2, prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
% %%
% % Add the current view to the view set.
vSet = addView(vSet, viewId,  absPose=relPose,Points=currPoints);
% 
% % Store the point matches between the previous and the current views.
vSet = addConnection(vSet, viewId-1, viewId, Matches=indexPairs);
prevFeatures = currFeatures;
prevPoints   = currPoints;  

%% 4. SCALE - TBD
clear worldPose* relPose*

viewId=5000
gcpPoints1 = cornerPoints(squeeze(pointhandles(1,:,:)));
gcpPoints2 = cornerPoints(squeeze(pointhandles(viewId,:,:)));

worldPose1 = estworldpose(squeeze(pointhandles(1,:,:)),gcp_xyz(:,:), cameraParams.Intrinsics);
worldPose2_true = estworldpose(squeeze(pointhandles(viewId,:,:)),gcp_xyz(:,:), cameraParams.Intrinsics);

figure(1);clf
scatter3(gcp_xyz(:,1), gcp_xyz(:,2), gcp_xyz(:,3), 50, colors(1:length(gcp_xyz),:),'filled')
hold on
plotCamera(AbsolutePose=worldPose1)
plotCamera(AbsolutePose=worldPose2_true, Opacity=0)
%%


% get relative pose of camera2
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));
prevFeatures = extractFeatures(prevI, prevPoints);

I = undistortImage(im2gray(readimage(images, viewId)), intrinsics);
[currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints);
[relPose2, inlierIdx] = helperEstimateRelativePose(prevPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)), intrinsics);
showMatchedFeatures(prevI, I, prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
%%
worldPose2 = rigidtform3d(worldPose1.R * relPose2.R, (worldPose1.Translation' + worldPose1.R' * relPose2.Translation')')
%worldPose2.R = worldPose1.R * relPose2.R;
%worldPose2.Translation = (worldPose1.Translation' + worldPose1.R' * relPose2.Translation')'

%
camMatrix1 = cameraProjection(intrinsics, pose2extr(worldPose1));
camMatrix2 = cameraProjection(intrinsics, pose2extr(worldPose2));

%worldPoints1 = img2world2d(gcpPoints1,pose2extr(worldPose1),intrinsics);
%worldPoints2 = img2world2d(gcpPoints2,pose2extr(worldPose2),intrinsics);

%projGCP1 = img2world2d(world2img(gcp_xyz, pose2extr(worldPose1), intrinsics), pose2extr(worldPose1), intrinsics);
%projGCP2 = img2world2d(world2img(gcp_xyz, pose2extr(worldPose2), intrinsics), pose2extr(worldPose2), intrinsics);

%scale = (sum(sqrt((worldPoints2 - worldPoints1).^2),2) ./ sum(sqrt((gcpPoints2.Location - gcpPoints1.Location).^2),2))
[worldPoints,ee] = triangulate(gcpPoints1, gcpPoints2, camMatrix1, camMatrix2);


figure(1);clf
scatter3(gcp_xyz(:,1), gcp_xyz(:,2), gcp_xyz(:,3), 50, colors(1:length(gcp_xyz),:),'filled')
hold on
scatter3(worldPoints(:,1), worldPoints(:,2), worldPoints(:,3), 100, colors(1:length(gcp_xyz),:),'LineWidth', 3)
plotCamera(AbsolutePose=worldPose1)
plotCamera(AbsolutePose=worldPose2)
% Distances
% Euclidean Distance between every GCP in z=real plane
clear trueDistance3d
for ii = 1:size(gcp_xyz,1)
    for jj = ii+1:size(gcp_xyz,1)
        trueDistance3d(ii,jj) = sqrt((gcp_xyz(ii,1) - gcp_xyz(jj,1)).^2 + (gcp_xyz(ii,2) - gcp_xyz(jj,2)).^2+ (gcp_xyz(ii,3) - gcp_xyz(jj,3)).^2);
    end
end
trueDistance3d

% Euclidean Distance between every preojected point in z=real plane
clear projDistance3d
for ii = 1:size(gcp_xyz,1)
    for jj = ii+1:size(gcp_xyz,1)
        projDistance3d(ii,jj) = sqrt(( worldPoints(ii,1) -  worldPoints(jj,1)).^2 + ( worldPoints(ii,2) -  worldPoints(jj,2)).^2+ ( worldPoints(ii,3) -  worldPoints(jj,3)).^2);
    end
end
projDistance3d

scale = nanmedian(trueDistance3d ./ projDistance3d, 'all')
%%
scale = 0.25
worldPose2_scale = rigidtform3d(worldPose1.R * relPose2.R, (worldPose1.Translation' + scale * worldPose1.R' * relPose2.Translation')')

%

camMatrix1 = cameraProjection(intrinsics, pose2extr(worldPose1));
camMatrix2 = cameraProjection(intrinsics, pose2extr(worldPose2_scale));

%worldPoints1 = img2world2d(gcpPoints1,pose2extr(worldPose1),intrinsics);
%worldPoints2 = img2world2d(gcpPoints2,pose2extr(worldPose2),intrinsics);

%projGCP1 = img2world2d(world2img(gcp_xyz, pose2extr(worldPose1), intrinsics), pose2extr(worldPose1), intrinsics);
%projGCP2 = img2world2d(world2img(gcp_xyz, pose2extr(worldPose2), intrinsics), pose2extr(worldPose2), intrinsics);

%scale = (sum(sqrt((worldPoints2 - worldPoints1).^2),2) ./ sum(sqrt((gcpPoints2.Location - gcpPoints1.Location).^2),2))
[worldPoints,ee] = triangulate(gcpPoints1, gcpPoints2, camMatrix1, camMatrix2);


figure(1);clf
scatter3(gcp_xyz(:,1), gcp_xyz(:,2), gcp_xyz(:,3), 50, colors(1:length(gcp_xyz),:),'filled')
hold on
scatter3(worldPoints(:,1), worldPoints(:,2), worldPoints(:,3), 100, colors(1:length(gcp_xyz),:),'LineWidth', 3)
plotCamera(AbsolutePose=worldPose1)
%plotCamera(AbsolutePose=worldPose2)
plotCamera(AbsolutePose=worldPose2_scale, Opacity = 0)
% Distances
% Euclidean Distance between every GCP in z=real plane
clear trueDistance3d
for ii = 1:size(gcp_xyz,1)
    for jj = ii+1:size(gcp_xyz,1)
        trueDistance3d(ii,jj) = sqrt((gcp_xyz(ii,1) - gcp_xyz(jj,1)).^2 + (gcp_xyz(ii,2) - gcp_xyz(jj,2)).^2+ (gcp_xyz(ii,3) - gcp_xyz(jj,3)).^2);
    end
end
trueDistance3d

% Euclidean Distance between every preojected point in z=real plane
clear projDistance3d
for ii = 1:size(gcp_xyz,1)
    for jj = ii+1:size(gcp_xyz,1)
        projDistance3d(ii,jj) = sqrt(( worldPoints(ii,1) -  worldPoints(jj,1)).^2 + ( worldPoints(ii,2) -  worldPoints(jj,2)).^2+ ( worldPoints(ii,3) -  worldPoints(jj,3)).^2);
    end
end
projDistance3d
%% 5. REPEAT PROCESS FOR EACH PICTURE

for viewId = 3:50
    viewId
    % Read and display the next image
    Irgb = readimage(images, (viewId-1)*100);
    
    % Convert to gray scale and undistort.
    I = undistortImage(im2gray(Irgb), intrinsics);
   
    % CAN INCLUDE HORIZON HERE
    % [horizon_line(viewId,:)] = get_horizon(I, sky, water);
    % HorizonPts(viewId,:) = horizon_line(viewId,1)*x + horizon_line(viewId,2);
    % currPoints = vertcat(currPoints, SURFPoints([x; HorizonPts(viewId,:)]', Metric=selectStrongest(currPoints,1).Metric));
    % indexPairs = vertcat(indexPairs, [numPoints+1:numPoints+length(x); numPoints+1:numPoints+length(x)]');

    % Eliminate outliers from feature matches.
    [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(prevPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    R_og(viewId) = rotation;
    indexPairs = indexPairs(inlierIdx, :);

    vSet = addView(vSet, viewId, Points=currPoints, Features=currFeatures);
     
    % % Store the point matches between the previous and the current views.
    vSet = addConnection(vSet, viewId-1, viewId, Matches=indexPairs);
    showMatchedFeatures(prevI, I, prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
    title(['ViewId = ' char(string(viewId))])
    pause(0.5)
   
    % prevI = imwarp(I, R(viewId), OutputView=imref2d(size(I)));
    % prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
    % numPoints = 500;
    % prevPoints = selectUniform(prevPoints, numPoints, size(prevI));
    % 
    % prevFeatures = extractFeatures(prevI, prevPoints);

    prevPoints = currPoints;
    prevFeatures = currFeatures;
    % perc_20 = min(y)/5;
    % sky =  round([mean(x) min(y) - perc_20]);
    % water = round([mean(x) max(y) + perc_20]);


    % Match points between the previous and the current image.
   [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints);

    % Eliminate outliers from feature matches.
    [relPose, inlierIdx] = helperEstimateRelativePose(prevPoints(indexPairs(:,1)),...
        currPoints(indexPairs(:, 2)), intrinsics);
    indexPairs = indexPairs(inlierIdx, :);

    vSet = addView(vSet, viewId, absPose=relPose, Points=currPoints);
     
    % % Store the point matches between the previous and the current views.
    vSet = addConnection(vSet, viewId-1, viewId, Matches=indexPairs);
    showMatchedFeatures(readimage(images, (viewId-2)*100), readimage(images, (viewId-1)*100), prevPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
    pause(0.5)
   
    prevFeatures = currFeatures;
    prevPoints   = currPoints;  
    prevPoints = currPoints;
    prevFeatures = currFeatures;
    % perc_20 = min(y)/5;
    % sky =  round([mean(x) min(y) - perc_20]);
    % water = round([mean(x) max(y) + perc_20]);
end
%% RECOVER EXTRINSICS

figure
% worldPose1 = estworldpose(squeeze(pointhandles(1,:,:)),gcp_xyz(:,:), cameraParams.Intrinsics);
plotCamera(AbsolutePose=worldPose1)


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
