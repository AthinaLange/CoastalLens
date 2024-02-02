function [Products, panorama, tforms] = extrinsics_pano(images, Method, intrinsics, Products, worldPose, extrinsicsInitial)



%% Compute projective transformation of images in reference to previous frame
clear prev*

viewId = 1;
I = im2gray(readimage(images, 1));
[m, n, ~] = size(I);
[prevPoints] = detectFeatures(I, Method);
[prevFeatures, prevPoints] = extractFeatures(I, prevPoints);

for viewId = 2:length(images.Files)
    viewId
    clear curr*
    I = im2gray(readimage(images, viewId));
    imageSize(viewId,:) = size(I);
    
    % Detect and extract SURF features for I(n).
    [currPoints] = detectFeatures(I, Method);
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
%%
% avgXLim = mean(xlim, 2);
% [~,idx] = sort(avgXLim);
% centerIdx = floor((numel(tforms)+1)/2);
% 
% centerImageIdx = idx(centerIdx);
% Tinv = invert(tforms(centerImageIdx));
% for i = 1:numel(tforms)    
%     tforms(i).A = Tinv.A * tforms(i).A;
% end
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

figure
imshow(panorama)
%% Show grid on original image
%find orientation of original image in panoramaView
% I = readimage(images, 1);   
% warpedImage = imwarp(I, tforms(1), 'OutputView', panoramaView);
% mask = imwarp(true(size(I,1),size(I,2)), tforms(1), 'OutputView', panoramaView);
% BW = boundarymask(mask);
% figure(1);clf
% image(labeloverlay(panorama,BW,'Transparency',0))
% [row, col] = find(BW == 1, 1,'first');
% viewId=1;
% 
% 
% pp=1;
% [xyz, Xout, Yout, Z] = getCoords(Products(pp), extrinsics(1,:));
% iP = round(world2img(xyz, pose2extr(worldPose), intrinsics)) + [col row];
% clf
% image(labeloverlay(warpedImage,BW,'Transparency',0))
% hold on
% %scatter(iP(:,1), iP(:,2), 10, 'r', 'filled')
% origin_id = find(min(abs(xyz(:,1)-x2)) ==abs(xyz(:,1)-x2) & min(abs(xyz(:,2)-y2)) ==abs(xyz(:,2)-y2));
% scatter(iP(origin_id,1), iP(origin_id,2), 40, 'g', 'filled')

%% Get Points
for pp = 1:length(Products)
    [xyz, Xout, Yout, Z] = getCoords(Products(pp), extrinsicsInitial);
    Products(pp).localX = Xout;
    Products(pp).localY = Yout;
    Products(pp).localZ = Z;

    iP = round(world2img(xyz, pose2extr(worldPose), intrinsics))+[col row];

    for viewId = 1:length(images.Files)
        if rem(viewId,10*30)==0
            viewId
        end
        I = imwarp(undistortImage(readimage(images, viewId), intrinsics), tforms(viewId), 'OutputView', panoramaView);

        clear Irgb_temp
        for ii = 1:length(xyz)
            if any(iP(ii,:) <= 0) || any(iP(ii,[2 1]) >= intrinsics.ImageSize)
                Irgb_temp(ii, :) = uint8([0 0 0]);
            else
                Irgb_temp(ii, :) = I(iP(ii,2), iP(ii,1),:);
            end
        end
        if contains(Products(pp).type, 'Grid')
            Products(pp).Irgb_2d(viewId, :,:,:) = reshape(Irgb_temp, size(Xout,1), size(Xout,2), 3);
        else
            Products(pp).Irgb_2d(viewId, :,:) = Irgb_temp;
        end


    end
end

% %%
% figure(2);clf
% image(panorama)
% 
% 
% figure(1);clf
% %tiledlayout(3,3)
% pp=1
% for ii = length(images.Files)
%     nexttile()
%     imshowpair(squeeze(Products(pp).Irgb_2d(1,:,:,:)), squeeze(Products(pp).Irgb_2d(ii,:,:,:)))
%     title(ii)
% end
% 
% figure(3);clf
% pp=2
% image(Products(pp).Irgb_2d)
% 


%%

end




%% FUNCTIONS

function [xyz, Xout, Yout, Z] = getCoords(Products, extrinsics)

[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);
localExtrinsics = localTransformExtrinsics([x2 y2], Products.angle-270, 1, extrinsics);


if contains(Products.type, 'Grid')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;

    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    [iX, iY]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));

    % DEM stuff
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    iZ=iX*0+iz;

    X=iX; Y=iY; Z=iZ;
    [Xout, Yout]=localTransformEquiGrid([x2 y2], Products.angle-270,1,iX,iY);
    Z=Xout.*0+iz;

    xyz = [Xout(:) Yout(:) Z(:)];


elseif contains(Products.type, 'xTransect')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;
    iy = y2 + Products.y;

    X = [ixlim(1):Products.dx:ixlim(2)]';
    Y = X.*0+iy;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = X.*0 + iz;
    %Xout=X-x2;
    %Yout=Y-y2;
    [ Xout, Yout]= localTransformPoints([x2 y2], Products.angle-270,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
elseif contains(Products.type, 'yTransect')
    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    ix = x2 + Products.x;

    Y = [iylim(1):Products.dy:iylim(2)]';
    X = Y.*0+ix;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = Y.*0 + iz;
    [ Xout, Yout]= localTransformPoints([x2 y2],Products.angle-270,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
end
xyz = xyz+[x2 y2 0];

end

