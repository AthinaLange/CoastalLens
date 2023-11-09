%% feature detection
%
%
%
%
%



cd('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01')
imgA = rgb2gray(imread('images_10Hz/Frame_0001.jpg'));

imgB = rgb2gray(imread('images_10Hz/Frame_0005.jpg'));


figure(1);clf
imshowpair(imgA,imgB)

ptThresh = 0.1;
pointsA = detectFASTFeatures(imgA,MinContrast=ptThresh);
pointsB = detectFASTFeatures(imgB,MinContrast=ptThresh);

% Display corners found in images A and B.
figure
imshow(imgA)
hold on
plot(pointsA)
title('Corners in A')


% Extract FREAK descriptors for the corners
[featuresA,pointsA] = extractFeatures(imgA,pointsA);
[featuresB,pointsB] = extractFeatures(imgB,pointsB);

indexPairs = matchFeatures(featuresA,featuresB);
pointsA = pointsA(indexPairs(:,1),:);
pointsB = pointsB(indexPairs(:,2),:);



figure
showMatchedFeatures(imgA,imgB,pointsA,pointsB)
legend('A','B')

%%
[tform,inlierIdx] = estgeotform2d(pointsB,pointsA,'affine');
pointsBm = pointsB(inlierIdx,:);
pointsAm = pointsA(inlierIdx,:);
imgBp = imwarp(imgB,tform,OutputView=imref2d(size(imgB)));
pointsBmp = transformPointsForward(tform,pointsBm.Location);
figure
showMatchedFeatures(imgA,imgBp,pointsAm,pointsBmp)
legend('A','B')