clc
clearvars
close all

% Set camera pose and parameters
H = 10.7;
inc = 75*pi/180;
roll = 0*pi/180;
azi = 0*pi/180;
load('intrinsicMatrix.mat')

% Establish domain
tMin = 0;  % sec
tMax = 60*60*1;  % sec, use long time for smooth Lambda Results
T = tMax-tMin;
xMin = -10;  % m
xMax = 10;  % m
yMin = 30;  % m
yMax = 50;  % m
A = (yMax-yMin)*(xMax-xMin);  % m^2
 
% Set breaker characteristics
cAvg = 3;   % m/s
cStd = 1;   % m/s
LAvg = 3;   % breaker crest length, m (constant) 
TAvg = 2;   % breaking duration, sec (constant) 
breakerDirX = true;  % direction of breaking: x = true, y = false

% Set Lambda probability density function
dc = 0.25;  % m/s
cVec = -2:dc:8;
lambdaPdf = normpdf(cVec,cAvg,cStd);

% Determine number of breakers needed for chosen breaking rate (or just set
% numBreakers directly)
brkRate = 120/3600; % Hz
numBreakers = floor(brkRate*A*T*dc/(TAvg*LAvg*sum(lambdaPdf.*cVec*dc)));
lTotal = TAvg*LAvg*numBreakers*sum(lambdaPdf*dc)/(A*T);
LambdaInput = lTotal*lambdaPdf;

% Randomly sample position, time, and speed of each breaker
xCenter = xMin + (xMax-xMin)*rand(numBreakers,1);
yCenter = yMin + (yMax-yMin)*rand(numBreakers,1);
tBegin = tMin + T*rand(numBreakers,1);
cRand = cAvg + cStd*randn(numBreakers,1);

% Simulate breaker moving forward in time
dt = 1/15;  % "Frame Rate" of observations
distTraveled = cRand*(0:dt:TAvg);   % vector of distance traveled by breaker
numTimeSteps = TAvg/dt + 1;

% Calculate positions of breaker end points in time
if breakerDirX
    x1 = repmat(xCenter,[1,numTimeSteps])+distTraveled;
    x2 = repmat(xCenter,[1,numTimeSteps])+distTraveled;
    y1 = repmat(yCenter-LAvg/2,[1,numTimeSteps]);
    y2 = repmat(yCenter+LAvg/2,[1,numTimeSteps]);
else
    x1 = repmat(xCenter-LAvg/2,[1,numTimeSteps]);
    x2 = repmat(xCenter+LAvg/2,[1,numTimeSteps]);
    y1 = repmat(yCenter,[1,numTimeSteps])+distTraveled;
    y2 = repmat(yCenter,[1,numTimeSteps])+distTraveled;
end

% Set camera motion frequency and amplitude, then find height for each
% time during breaker duration
timeElapsed = repmat(0:dt:TAvg,[numBreakers,1]);
tMatrix = repmat(tBegin,[1,numTimeSteps])+timeElapsed;
amp = 1;    % m (remember wave height is twice wave amplitude)
freq = 1/8;  % Hz
radFreq = 2*pi*freq;
HMatrix = amp*cos(tMatrix*radFreq);

% Determine falsely observed position of breaker endpoints due to camera
% motion
x1Obs = zeros(numBreakers,numTimeSteps);
y1Obs = zeros(numBreakers,numTimeSteps);
x2Obs = zeros(numBreakers,numTimeSteps);
y2Obs = zeros(numBreakers,numTimeSteps);
for i = 1:numBreakers
    for j= 1:numTimeSteps
        [dx1,dy1,~,~] = ProjectionErrorsXY(x1(i,j),y1(i,j),H,inc,roll,azi,K,HMatrix(i,j),0,0,0);
        x1Obs(i,j) = x1(i,j)+dx1;
        y1Obs(i,j) = y1(i,j)+dy1;
        [dx2,dy2,~,~] = ProjectionErrorsXY(x2(i,j),y2(i,j),H,inc,roll,azi,K,HMatrix(i,j),0,0,0);
        x2Obs(i,j) = x2(i,j)+dx2;
        y2Obs(i,j) = y2(i,j)+dy2;
    end
end

% calculate true and observed breaker speeds and lengths, based on x and y
% coordinates of breaker endpoints
if breakerDirX
    cMatrixTrue = (diff(x1,1,2)/dt+diff(x2,1,2)/dt)/2;
    LMatrixTrue = y2-y1;
    cMatrixObs = (diff(x1Obs,1,2)/dt+diff(x2Obs,1,2)/dt)/2;
    LMatrixObs = y2Obs-y1Obs;
else
    cMatrixTrue = (diff(y1,1,2)/dt+diff(y2,1,2)/dt)/2;
    LMatrixTrue = x2-x1;
    cMatrixObs = (diff(y1Obs,1,2)/dt+diff(y2Obs,1,2)/dt)/2;
    LMatrixObs = x2Obs-x1Obs;
end
LMatrixTrue = LMatrixTrue(:,1:(numTimeSteps-1));
LMatrixObs = LMatrixObs(:,1:(numTimeSteps-1));

% calculate true and observed lambda
LambdaTrue = nan(length(cVec),1);
LambdaObs = nan(length(cVec),1);
for i=1:length(cVec)
    ind = cMatrixTrue>(cVec(i)-dc/2) & cMatrixTrue<(cVec(i)+dc/2);
    LambdaTrue(i) = sum(LMatrixTrue(ind))/(A*dc*T/dt);
    indObs = cMatrixObs>(cVec(i)-dc/2) & cMatrixObs<(cVec(i)+dc/2);
    LambdaObs(i) = sum(LMatrixObs(indObs))/(A*dc*T/dt);
end

% show 10 example crests
figure(1)
hold on
set(gca,'xlim',[xMin xMax],'ylim',[yMin yMax])
for i=1:10
    for j=1:numTimeSteps
        plot([x1(i,j),x2(i,j)],[y1(i,j),y2(i,j)],'-r')
        plot([x1Obs(i,j),x2Obs(i,j)],[y1Obs(i,j),y2Obs(i,j)],'-b')
        pause(.01)
    end
end

% Plot input, true, and observed Lambdas
figure(2)
plot(cVec,LambdaTrue,'-r')
hold on
plot(cVec,LambdaInput,'-k')
plot(cVec,LambdaObs,'-b')
hold off


