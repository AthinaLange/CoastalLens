function [R, relPose_all, id_bad_data] = fd_wpanorama(images, intrinsics, Method, varargin)



%% Options
options.ImageFlag = 0;
options.save_dir = pwd;
options.mask = ones(size(readimage(images,1)));
options.relativePoseFlag = 0;
options.worldPose = rigidtform3d;
options.Products = struct();

options = parseOptions( options , varargin );
if options.relativePoseFlag == 1
    if ~isfield(options.Products, 'lat') || ~isfield(options.Products, 'lon')
        options.relativePoseFlag = 0;
        disp('Products does not have a defined lat/lon for the origin, and relative Pose will not be calculated.')
    end
end

%%
clear prev*

viewId = 1;
I = undistortImage(im2gray(readimage(images, 1)), intrinsics);
[m, n, ~] = size(I);
[I] = apply_binary_mask(I, options.mask);
prevI = zeros([m+m/2 n+n/2 1]); 
%

% Detect features.
distance_from_border = 10;
[prevPoints] = detectFeatures(I, Method);%
% remove image border points;
 id = [find(prevPoints.Location(:,1) > n - distance_from_border)' ...
         find(prevPoints.Location(:,1) < distance_from_border)' ...
         find(prevPoints.Location(:,2) > m - distance_from_border)'];
prevPoints(id)=[];
% remove mask border points
for ii=length(prevPoints.Location):-1:1
    y=round(prevPoints.Location(ii,2)); % vertical
    x=round(prevPoints.Location(ii,1)); % horizontal
    aa=I(y-distance_from_border:y, x);
    if min(aa(:)) == 0
        prevPoints(ii)=[];
    end
end
numPoints = 500;
%prevPoints = selectUniform(prevPoints, numPoints, size(prevI));
%%
% push to bigger image
prevI(m/4+1:m+m/4, n/4+1:n+n/4) = I; 
prevPoints.Location= prevPoints.Location + [n/4 m/4];

% Extract features.
[prevFeatures, prevPoints] = extractFeatures(prevI, prevPoints);

% Panorama setup
blender = vision.AlphaBlender('Operation', 'Blend', 'MaskSource', 'Input port', 'Opacity',1);
panorama = zeros([m+m/2 n+n/2 3], 'like', I);

panoramaView = imref2d([size(panorama,1) size(panorama,2)], [-n/4 n+n/4],  [-m/4 m+m/4]);

if options.relativePoseFlag == 1
    relPose_all.Adjusted(viewId) = options.worldPose;
end
id_bad_data = [];
%%
for viewId = 2:length(images.Files)
    viewId = 200

    clear curr*
    Irgb = readimage(images, (viewId));
    I = undistortImage(im2gray(Irgb), intrinsics);
    [I] = apply_binary_mask(I, options.mask);

    % Get current picture features
    [currPoints] = detectFeatures(I, Method);%

    % remove image border points;
     id = [find(currPoints.Location(:,1) > n - distance_from_border)' ...
             find(currPoints.Location(:,1) < distance_from_border)' ...
             find(currPoints.Location(:,2) > m - distance_from_border)'];
    currPoints(id)=[];
    % remove mask border points
    for ii=length(currPoints.Location):-1:1
        y=round(currPoints.Location(ii,2)); % vertical
        x=round(currPoints.Location(ii,1)); % horizontal
        aa=I(y-distance_from_border:y, x);
        if min(aa(:)) == 0
            currPoints(ii)=[];
        end
    end

   %currPoints  = selectUniform(currPoints, numPoints, size(I));
    % push to bigger image
    currI = zeros([m+m/2 n+n/2 1]); 
    currI(m/4+1:m+m/4, n/4+1:n+n/4) = I; 
    currPoints.Location= currPoints.Location + [n/4 m/4];

    % extract and match features
    [currFeatures, currPoints]  = extractFeatures(currI, currPoints);
    %%
    indexPairs = matchFeatures(prevFeatures, currFeatures, 'Unique', true, 'MaxRatio', 0.4);

    % estimate transformation
    matchedPoints1 = prevPoints(indexPairs(:,1)); if ~isnumeric(matchedPoints1);matchedPoints1 = matchedPoints1.Location;end
    matchedPoints2 = currPoints(indexPairs(:, 2)); if ~isnumeric(matchedPoints2);matchedPoints2 = matchedPoints2.Location;end

    clf;showMatchedFeatures(prevI,currI, matchedPoints1, matchedPoints2);
    [rotation, ~] = estgeotform2d(matchedPoints2, matchedPoints1,'similarity');
   
    %%
    R(viewId) = rotation;

    try
        if options.relativePoseFlag == 1
            % % relative pose
            [relPose, ~] = helperEstimateRelativePose(matchedPoints1, matchedPoints2, intrinsics);

            if length(relPose) ~= 1
                % Do first check if image projection is very wrong - origin of grid should be within image frame
                [UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(options.Products(1).lat, options.Products(1).lon);
                coords = horzcat(UTMEasting, UTMNorthing, 5.4);
                for rr = length(relPose):-1:1
                    aa = options.worldPose.A *  relPose(rr).A;
                    absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                    iP = world2img(coords, pose2extr(absPose), intrinsics);
                    % if origin of grid is projected outside of image -> problem
                    if any(any(iP(:)> max(intrinsics.ImageSize))) || any(any(iP(:)< 0))
                        relPose(rr) = [];
                    end % if any(any(iP(:)> max(intrinsics.ImageSize))) || any(any(iP(:)< 0))
                end % for rr = length(relPose):-1:1

                if length(relPose) ~= 1
                    % find projection point that is closest Euclidian distance to previous frame origin point
                    previP = world2img(coords, pose2extr(relPose_all.Adjusted(viewId-1)), intrinsics);
                    clear dist
                    for rr = 1:length(relPose)
                        aa = options.worldPose.A *  relPose(rr).A;
                        absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                        iP = world2img(coords, pose2extr(absPose), intrinsics);
                        dist(rr) = pdist2(previP, iP);
                    end % for rr = 1:length(relPose)
                    [~,i]=min(dist);
                    relPose = relPose(i);
                end % if length(relPose) ~= 1
            end  % if length(relPose) ~= 1

            relPose_all.relative(viewId) = relPose;
            aa = options.worldPose.A *  relPose.A;
            absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
            relPose_all.Adjusted(viewId) = absPose;
        end

        if options.ImageFlag == 1
            if viewId == 2
                disp(viewId)
                figure(1);clf
                J1 = showMatchedFeatures(undistortImage(readimage(images, 1), intrinsics), undistortImage(readimage(images, viewId), intrinsics), matchedPoints1, matchedPoints2);
                saveas(gca, 'temp1.jpg')
                figure(2);clf
                J2 = imshowpair(undistortImage(readimage(images, 1), intrinsics), ...
                    imwarp(undistortImage(readimage(images, viewId), intrinsics), rotation, OutputView=imref2d(size(readimage(images, viewId-1)))));
                saveas(gca, 'temp2.jpg')
            else
                disp(viewId)
                figure(1);clf
                J1 = showMatchedFeatures(panorama, undistortImage(readimage(images, viewId), intrinsics), matchedPoints1, matchedPoints2);
                saveas(gca, 'temp1.jpg')
                figure(2);clf
                J2 = imshowpair(panorama, ...
                    imwarp(undistortImage(readimage(images, viewId), intrinsics), rotation, OutputView=imref2d(size(readimage(images, viewId-1)))));
                saveas(gca, 'temp2.jpg')
            end
            hFig = figure(4);clf
            imshowpair(imread('temp1.jpg'), imread('temp2.jpg'),'montage')
            title(sprintf('Method = %s   Time = %.1f min', Method, viewId/10/60))
            saveas(hFig, sprintf('%s/warped_%.2fsec.jpg', options.save_dir, viewId/10))
        end

    catch
        id_bad_data = [id_bad_data viewId];
    end

    %% CREATE PANORAMA BACKGROUND IMAGE
    warpedImage = imwarp(undistortImage(readimage(images, viewId), intrinsics), rotation, 'OutputView', panoramaView);
    panorama = step(blender, panorama, warpedImage);
    figure(5);clf
    imshow(panorama)
end %for viewId = 2:length(images.Files)
close all



end

%% FUNCTIONS


