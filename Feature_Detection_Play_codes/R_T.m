%% MONOCULAR VISUAL ODOMETRY
clear all
close all

 hh=1
extract_Hz = 10
%% Torrey
%odir='/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/'
odir = '/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/';    
imageDirectory = [odir 'images_10Hz/']
images = imageDatastore(imageDirectory)

load([odir 'Processed_data/20211026_Torrey_01_IOEOInitial.mat'], 'extrinsics', 'intrinsics')
intrinsicsCIRN = intrinsics;
load([odir 'Processed_data/20211026_Torrey_01_IO.mat'], 'cameraParams')
intrinsics = cameraParams.Intrinsics;

% load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/Processed_data/20230208_Blacks_01_IOEOInitial.mat', 'extrinsics', 'intrinsics')
% intrinsicsCIRN = intrinsics;
% load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/Processed_data/20230208_Blacks_01_IO.mat', 'cameraParams')
% intrinsics = cameraParams.Intrinsics;



%% Get inital World Coordinates
images = imageDatastore(imageDirectory);
images.Files = images.Files(1:3000);

% Get initial camera pose
if ~exist('worldPose', 'var')
    select_image_gcp
    select_target_gcp
    world_gcp = target_gcp;
    worldPose = estworldpose(image_gcp,world_gcp, cameraParams.Intrinsics);
%load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20230208_Blacks/01/worldPose.mat')
end
%% Get features of 1st frame
% Create an empty imageviewset object to manage the data associated with each view.
vSet = imageviewset;

viewId = 1
prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics); 
cutoff = round(size(prevI,1)*(1/2));

% Detect features. 
prevPoints = detectSURFFeatures(prevI(cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+cutoff;
numPoints = 2000;
prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

% Extract features. 
prevFeatures = extractFeatures(prevI, prevPoints);

% Add the first view.
vSet = addView(vSet, viewId, absPose=worldPose, Points=prevPoints, Features=prevFeatures);

close all 
ogI = prevI;
ogPoints = prevPoints; 
ogFeatures = prevFeatures;

%% Get Essential matrix and relative pose of all subsequent images

for viewId = 2:100%length(images.Files)
    viewId
     % Read and display the next image
    Irgb = readimage(images, (viewId));
    
    % Convert to gray scale and undistort.
    I = undistortImage(im2gray(Irgb), intrinsics);

    % ---------- Match points between the previous and the current image. ----------
    % Detect and extract features from the current image.
    currPoints   = detectSURFFeatures(I(cutoff:end,:), 'MetricThreshold', 500); currPoints.Location(:,2)=currPoints.Location(:,2)+cutoff;
    currPoints   = selectUniform(currPoints, numPoints, size(I));
    currFeatures = extractFeatures(I, currPoints);
    
    % Match features between the previous and current image.
    indexPairs = matchFeatures(ogFeatures, currFeatures, 'Unique', true, 'MaxRatio', 0.9);

    % ---------- Estimate Essential matrix. ----------
    [E, inlierIdx] = estimateEssentialMatrix(ogPoints(indexPairs(:,1)),...
       currPoints(indexPairs(:, 2)), intrinsics);
    
    % Get the epipolar inliers.
    indexPairs = indexPairs(inlierIdx,:);
        
    % Compute the camera pose from the fundamental matrix. Use half of the
    % points to reduce computation.
    [relPose, validPointFraction] = estrelpose(E, intrinsics, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
    R.length(viewId) = length(relPose);
    if length(relPose) == 1
        
        R.relPose(viewId) = relPose;
        aa = worldPose.A *  relPose.A;
        absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
        vSet = addView(vSet, viewId, absPose=absPose, Features=currFeatures, Points=currPoints);
        vSet = addConnection(vSet, 1, viewId, Matches=indexPairs);

    elseif length(relPose) == 2
        R.relPose(viewId) = relPose(1);
        R.relPose_alt(viewId) = relPose(2);
        vSet = addView(vSet, viewId, Points=currPoints);
        vSet = addConnection(vSet, 1, viewId, Features=currFeatures, Matches=indexPairs);

    elseif length(relPose) == 4

        for ii = 1:length(relPose)
            imagePointsOG(ii,:,:) = world2img(world_gcp, pose2extr(worldPose), intrinsics);
            [imagePoints(ii,:,1),imagePoints(ii,:,2)] = transformPointsForward(relPose(ii),imagePointsOG(ii,:,1), imagePointsOG(ii,:,2), ones(size(imagePointsOG(ii,:,1),1), size(imagePointsOG(ii,:,1),2)));
        end
        id = unique([find(any(squeeze(imagePoints(:,:,1)) < 0,2)) find(any(squeeze(imagePoints(:,:,1)) > size(I,2),2)) ...
                            find(any(squeeze(imagePoints(:,:,2)) < 0,2)) find(any(squeeze(imagePoints(:,:,2)) > size(I,1),2))]);
        relPose(id)=[];

        R.relPose(viewId) = relPose(1);
        R.relPose_alt(viewId) = relPose(2);
        vSet = addView(vSet, viewId, Points=currPoints);
        vSet = addConnection(vSet, 1, viewId, Features=currFeatures, Matches=indexPairs);

     end

    prevI = I;
    prevPoints = currPoints;
    prevFeatures = currFeatures;
end

%% Map every Product pixel into camera worldPose
ii=1

Products(ii).x = min(Products(ii).xlim):Products(ii).dx:max(Products(ii).xlim);
Products(ii).y = min(Products(ii).ylim):Products(ii).dy:max(Products(ii).ylim);
[grid_x, grid_y] = meshgrid(Products(ii).x,Products(ii).y);
%%

load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/CPG_data/origin_Torrey.mat')
[UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(origin_grid(1), origin_grid(2))
[x,y] = meshgrid(-Products(ii).x([1 end]),Products(ii).y([1 end]));
grid_world = [x(:), y(:)];
grid_world(:,1)=grid_world(:,1)+UTMEasting; 
grid_world(:,2)=grid_world(:,2)+UTMNorthing; 
grid_image = world2img([grid_world zeros(length(x(:)),1)], pose2extr(worldPose), intrinsics)


%%
clf
plotCamera(absolutePose = worldPose)
hold on
grid on
plot3(extrinsics(1),extrinsics(2),extrinsics(3), '.', 'MarkerSize', 50)
set(gca, 'YDir', 'reverse')
plot3([UTMEasting UTMEasting], [UTMNorthing-300 UTMNorthing+300], [0 0], 'k-', 'LineWidth', 2)
plot3([UTMEasting-500 UTMEasting-500], [UTMNorthing-300 UTMNorthing+300], [0 0], 'k-', 'LineWidth', 2)
plot3([UTMEasting UTMEasting-500], [UTMNorthing-300 UTMNorthing-300], [0 0], 'k-', 'LineWidth', 2)
plot3([UTMEasting UTMEasting-500], [UTMNorthing+300 UTMNorthing+300], [0 0], 'k-', 'LineWidth', 2)
aa=img2world2d([0 0; 3840 0; 3840 2160; 0 2160], pose2extr(worldPose), intrinsics)
plot3(aa(:,1), aa(:,2),[0 0 0 0], '.', 'MarkerSize', 30)
plot3([UTMEasting extrinsics(1)], [UTMNorthing+300 extrinsics(2)], [0 extrinsics(3)], 'k-', 'LineWidth', 2)
plot3([UTMEasting extrinsics(1)], [UTMNorthing-300 extrinsics(2)], [0 extrinsics(3)], 'k-', 'LineWidth', 2)
plot3([UTMEasting-500 extrinsics(1)], [UTMNorthing-300 extrinsics(2)], [0 extrinsics(3)], 'k-', 'LineWidth', 2)
plot3([UTMEasting-500 extrinsics(1)], [UTMNorthing+300 extrinsics(2)], [0 extrinsics(3)], 'k-', 'LineWidth', 2)

%%
aa=img2world2d([0 0; 3840 0; 3840 2160; 0 2160], pose2extr(worldPose), intrinsics)
plot3(aa(1,1), aa(1,2),[0 0 0 0], '.', 'MarkerSize', 30)
plot3(aa(3,1), aa(3,2),[0 0 0 0], '.', 'MarkerSize', 30)
