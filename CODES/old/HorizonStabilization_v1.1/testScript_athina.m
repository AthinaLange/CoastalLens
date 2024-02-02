% ----------------------------------------------------------------------- %
% NOTE: Switch to  FindHorizonAlternate instead of FindHorizon if you have
% the image processing toolbox but not the computer vision toolbox.
% ----------------------------------------------------------------------- %

clc
clearvars -except cameraParams intrinsics extrinsics
close all

% load sample video frames
%load('SampleVideoFrames.mat')   % distortion already removed from images
VideoFrames = rgb2gray(imread('Processed_data/undistortImage.png'));
VideoFrames=VideoFrames(1:600,:);
% load camera parameters
%load('intrinsicMatrix.mat')     % from geometric calibration
K = cameraParams.Intrinsics.K;
% coordinates of whole image
[nv,nu,numFrames] = size(VideoFrames);
[uGrid,vGrid] = meshgrid(1:nu,1:nv);
ROI = [5,5,nv/2,nu-5];  % Hough transform ROI
H = extrinsics(3);%10.7;              % Change for your camera height
azi = extrinsics(4);%0*pi/180;         % Azimuth angle, change for your heading

% sample real-world coordinates
xLimits = [-20 20];
yLimits = [50 90];
nxBox = 256;
nyBox = 128;
[xBox1,yBox1] = meshgrid(linspace(xLimits(1),xLimits(2),nxBox),linspace(yLimits(1),yLimits(2),nyBox));

% sample image coordinates
uLimits = [nu/2-100 nu/2+100];
vLimits = [200 300];
[uBox2,vBox2] = meshgrid(uLimits(1):uLimits(2),vLimits(1):vLimits(2));

% Input stabilized camera pose
incStab = extrinsics(5);%75*pi/180;
rollStab = extrinsics(6);%0*pi/180;
aziStab = 0*pi/180;

% Find pixels of horizon in stabilized image
[thetaStab, rStab] = Angles2Horizon(incStab,rollStab,K);
uHor = [0 nu];
vHorStab = HorizonPixels(thetaStab,rStab,uHor);


% cycle through frames, find horizon (uncomment for different versions)
% If you do not have the computer vision toolbox, use FindHorizonAlternate

%[thetaMax, rMax, peakFrac, EdgeMatrix, ht, theta, r] = FindHorizon(VideoFrames,ROI,'canny');
%[thetaMax, rMax, peakFrac, EdgeMatrix, ht, theta, r] = FindHorizon(VideoFrames,ROI,'sobel'); 
%[thetaMax, rMax, peakFrac,EdgeMatrix] = FindHorizon(VideoFrames,ROI,'canny'); 
%[thetaMax, rMax,peakFrac] = FindHorizon(VideoFrames,ROI,'canny'); 
[thetaMax, rMax,peakFrac, EdgeMatrix, ht, theta, r] = FindHorizonAlternate(VideoFrames,ROI,'canny'); 
%[thetaMax, rMax, peakFrac,EdgeMatrix, ht, theta, r] = FindHorizonAlternate(VideoFrames,ROI,'sobel');
%[thetaMax, rMax, peakFrac, EdgeMatrix] = FindHorizonAlternate(VideoFrames,ROI,'canny'); 
%[thetaMax, rMax, peakFrac]= FindHorizonAlternate(VideoFrames,ROI,'canny');

% find camera angles and stabilize images
[inc, roll] = Horizon2Angles(thetaMax,rMax,K);
stabFrames = StabilizeImages(VideoFrames,inc,roll,azi,incStab,rollStab,aziStab,K);


for i=1:length(inc)
    % coordinate transformations
    [uBox2Stab, vBox2Stab] = Image2Image(uBox2,vBox2,inc(i),roll(i),azi,incStab,rollStab,aziStab,K);
    [xBox2, yBox2] = Image2World(uBox2,vBox2,H,inc(i),roll(i),azi,K);
    [uBox1, vBox1] = World2Image(xBox1,yBox1,H,inc(i),roll(i),azi,K);
    [uBox1Stab, vBox1Stab] = Image2Image(uBox1,vBox1,inc(i),roll(i),azi,incStab,rollStab,aziStab,K);
    
    % horizon from r,theta in original image
    vHor = HorizonPixels(thetaMax(i),rMax(i),uHor);
   
    figure(1)
    figureSize = [1 1 3.5 8];
    set(1,'units','inches','position',figureSize,'paperposition',figureSize,...
        'InvertHardCopy', 'off','color','w','DefaultTextFontSize',12,'DefaultAxesFontSize',12,...
        'DefaultAxesFontName', 'Times New Roman','DefaultTextFontname', 'Times New Roman')
    subplot(3,1,1)
    imagesc(uGrid(1,:),vGrid(:,1),VideoFrames(:,:,i))
    colormap('gray')
    set(gca,'cLim',[0 255],'xlim',[0 nu],'ylim',[0 nv],'ydir','reverse','Layer','top')
    hold on
    plot(uBox1(:,1),vBox1(:,1),'c')
    plot(uBox1(:,end),vBox1(:,end),'c');
    plot(uBox1(1,:),vBox1(1,:),'c');
    plot(uBox1(end,:),vBox1(end,:),'c');
    plot(uBox2(:,1),vBox2(:,1),'g');
    plot(uBox2(:,end),vBox2(:,end),'g');
    plot(uBox2(1,:),vBox2(1,:),'g');
    plot(uBox2(end,:),vBox2(end,:),'g');
    plot(uHor,vHor,'--r');
    hold off
    
    subplot(3,1,2)
    colormap('gray')
    imagesc(uGrid(1,:),vGrid(:,1),stabFrames(:,:,i))
    set(gca,'cLim',[0 255],'xlim',[0 nu],'ylim',[0 nv],'ydir','reverse','Layer','top')
    hold on
    plot(uBox1Stab(:,1),vBox1Stab(:,1),'c');
    plot(uBox1Stab(:,end),vBox1Stab(:,end),'c');
    plot(uBox1Stab(1,:),vBox1Stab(1,:),'c');
    plot(uBox1Stab(end,:),vBox1Stab(end,:),'c');
    plot(uBox2Stab(:,1),vBox2Stab(:,1),'g');
    plot(uBox2Stab(:,end),vBox2Stab(:,end),'g');
    plot(uBox2Stab(1,:),vBox2Stab(1,:),'g');
    plot(uBox2Stab(end,:),vBox2Stab(end,:),'g');
    plot(uHor,vHorStab,'--r');
    hold off
    
    subplot(3,1,3)
    pcolor(xBox2,yBox2,double(VideoFrames(vLimits(1):vLimits(2),uLimits(1):uLimits(2),i)))
    shading('flat')
    colormap('gray')
    set(gca,'cLim',[0 255],'xlim',[xLimits(1)-10,xLimits(2)+10],'ylim',[yLimits(1)-10,yLimits(2)+10],'Color',[0 0 0],'yaxislocation','right')
    hold on
    plot(xBox1(:,1),yBox1(:,1),'-c')
    plot(xBox1(:,end),yBox1(:,end),'-c')
    plot(xBox1(1,:),yBox1(1,:),'-c')
    plot(xBox1(end,:),yBox1(end,:),'-c')
    plot(xBox2(:,1),yBox2(:,1),'-g')
    plot(xBox2(:,end),yBox2(:,end),'-g')
    plot(xBox2(1,:),yBox2(1,:),'-g')
    plot(xBox2(end,:),yBox2(end,:),'-g')
    hold off
    
    figure(2)
    figureSize = [5 1 3 8];
    set(2,'units','inches','position',figureSize,'paperposition',figureSize,...
        'InvertHardCopy', 'off','color','w','DefaultTextFontSize',12,'DefaultAxesFontSize',12,...
        'DefaultAxesFontName', 'Times New Roman','DefaultTextFontname', 'Times New Roman')
    subplot(4,1,1)
    imagesc(uGrid(1,:),vGrid(:,1),VideoFrames(:,:,i))
    colormap('gray')
    set(gca,'cLim',[0 255],'xlim',[0 nu],'ylim',[0 nv],'ydir','reverse','Layer','top')
    
    subplot(4,1,2)
    imagesc(uGrid(1,:),vGrid(:,1),EdgeMatrix(:,:,i))
    colormap('gray')
    set(gca,'cLim',[0 1],'xlim',[0 nu],'ylim',[0 nv],'ydir','reverse','Layer','top')
    
    htI = ht(:,:,i);
    [maxHough,maxInd] = max(htI(:));
    subplot(4,1,3)
    imagesc(theta*180/pi,r,htI)
    set(gca,'cLim',[0 maxHough/2],'xlim',[0 180],'Layer','top','ydir','normal')
    colormap('gray')
    hold on
    plot(thetaMax(i)*180/pi,rMax(i),'ro','markersize',7)
    hold off
    
    subplot(4,1,4)
    imagesc(uGrid(1,:),vGrid(:,1),double(VideoFrames(:,:,i)))
    colormap('gray')
    set(gca,'cLim',[0 255],'xlim',[0 nu],'ylim',[0 nv],'ydir','reverse','Layer','top')
    hold on
    plot(uHor,vHor,'--r');
    hold off
    
    pause
    
end
