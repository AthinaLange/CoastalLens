% Finding the horizon line with the watershed and RANSAC algorithms


function [horizon_line] = get_horizon(I, sky, water)
    cutoff_lim = min(11, sky(2))-1;
    short_factor = sky(2)-cutoff_lim;
    I_small = I(short_factor : water(2)+cutoff_lim,:,:);
    
     %filteredImage = medfilt2(rgb2gray(I_small), [50,100]);
    gmag = max(gradmag(I),'tensor');
 %   filteredImage = imclose(rgb2gray(I_small),strel('rectangle', [10 50]));
  %  gmag = imgradient(filteredImage); 
    
    % get foreground and background points
    fgm = zeros(size(gmag,1), size(gmag,2));
    fgm(end-cutoff_lim:end,:) = 1;
    
    bgm = zeros(size(gmag,1), size(gmag,2));
    bgm(1:cutoff_lim, :) = 1;

    % Watershed
    gmag2 = imimposemin(gmag, bgm | fgm);
    W = watershed(gmag2);

    % Plot
    figure(3);clf
    labels = imdilate(W==0,ones(3,3)) + 2*bgm + 3*fgm;
    I4 = labeloverlay(I_small,labels);
    imshow(I4)
    title("Markers and Object Boundaries Superimposed on Original Image")

    figure(2);clf
    Lrgb = label2rgb(W,"jet","w","shuffle");
    imshow(Lrgb)
    title("Colored Watershed Label Matrix")

    
    % Get best fit line 

    i=find(W==0);
    [x,y]=meshgrid([1:size(I_small,2)],[1:size(I_small,1)]);
    ws_line = [x(i),y(i)+short_factor];

    %
    sampleSize = 2; % number of points to sample per trial
    maxDistance = 10; % max allowable distance for inliers
    
    fitLineFcn = @(points) polyfit(ws_line(:,1),ws_line(:,2),1); % fit function using polyfit
    evalLineFcn = ...   % distance evaluation function
      @(model, points) sum((ws_line(:, 2) - polyval(model, ws_line(:,1))).^2,2);
    
    [modelRANSAC, inlierIdx] = ransac(ws_line,fitLineFcn,evalLineFcn, ...
      sampleSize,maxDistance);
    %modelInliers = polyfit(ws_line(inlierIdx,1),ws_line(inlierIdx,2),1);
   % inlierPts = ws_line(inlierIdx,:);
   

    horizon_line = modelRANSAC;



end