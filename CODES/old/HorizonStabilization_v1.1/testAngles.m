clc
clearvars
close all

% load camera parameters
load('intrinsicMatrix.mat')     % from geometric calibration

% define square in x-y space for nadir test
xTest1 = [-1 1 1 -1 -1];  % 1 m^2 area
yTest1 = [-1 -1 1 1 -1];
% define square in x-y space for oblique test
xTest2 = [-1 1 1 -1 -1];  % 1 m^2 area
yTest2 = [10 10 11 11 10];
% define square in pixel space for nadir and oblique test
uTest = [300 300 400 400 300];  
vTest = [200 300 300 200 200];


H = 10;  % camera height of 10 meters

% find pixel coordinates of square for changing camera angles around nadir
[u_nadir_0,v_nadir_0] = World2Image(xTest1,yTest1,H,0,0,0,K);
[u_nadir_roll,v_nadir_roll] = World2Image(xTest1,yTest1,H,0,45*pi/180,0,K);
[u_nadir_pitch,v_nadir_pitch] = World2Image(xTest1,yTest1,H,10*pi/180,0,0,K);
[u_nadir_azimuth,v_nadir_azimuth] = World2Image(xTest1,yTest1,H,0,0,10*pi/180,K);

% find pixel coordinates of square for changing camera angles around nadir
[u_oblique_0,v_oblique_0] = World2Image(xTest2,yTest2,H,45*pi/180,0,0,K);
[u_oblique_roll,v_oblique_roll] = World2Image(xTest2,yTest2,H,45*pi/180,45*pi/180,0,K);
[u_oblique_pitch,v_oblique_pitch] = World2Image(xTest2,yTest2,H,45*pi/180+10*pi/180,0,0,K);
[u_oblique_azimuth,v_oblique_azimuth] = World2Image(xTest2,yTest2,H,45*pi/180,0,10*pi/180,K);

% find pixel coordinates of square for changing camera angles around nadir
[x_nadir_0,y_nadir_0] = Image2World(uTest,vTest,H,0,0,0,K);
[x_nadir_roll,y_nadir_roll] = Image2World(uTest,vTest,H,0,45*pi/180,0,K);
[x_nadir_pitch,y_nadir_pitch] = Image2World(uTest,vTest,H,10*pi/180,0,0,K);
[x_nadir_azimuth,y_nadir_azimuth] = Image2World(uTest,vTest,H,0,0,10*pi/180,K);

% find pixel coordinates of square for changing camera angles around nadir
[x_oblique_0,y_oblique_0] = Image2World(uTest,vTest,H,45*pi/180,0,0,K);
[x_oblique_roll,y_oblique_roll] = Image2World(uTest,vTest,H,45*pi/180,45*pi/180,0,K);
[x_oblique_pitch,y_oblique_pitch] = Image2World(uTest,vTest,H,45*pi/180+10*pi/180,0,0,K);
[x_oblique_azimuth,y_oblique_azimuth] = Image2World(uTest,vTest,H,45*pi/180,0,10*pi/180,K);

% plot
figure(1)
subplot(2,2,1)
plot(u_nadir_0,v_nadir_0,'-k')
hold('on')
plot(u_nadir_roll,v_nadir_roll,'-r')
plot(u_nadir_pitch,v_nadir_pitch,'-b')
plot(u_nadir_azimuth,v_nadir_azimuth,'-g')
hold('off')
xlabel('u [pixels]'), ylabel('v [pixels]')
title('Nadir, World to Image')
set(gca,'xLim',[0 720],'yLim',[0 480],'yDir','Reverse')
legend('Original','Roll','Incidence','Azimuth')

subplot(2,2,2)
plot(u_oblique_0,v_oblique_0,'-k')
hold('on')
plot(u_oblique_roll,v_oblique_roll,'-r')
plot(u_oblique_pitch,v_oblique_pitch,'-b')
plot(u_oblique_azimuth,v_oblique_azimuth,'-g')
hold('off')
xlabel('u [pixels]'), ylabel('v [pixels]')
title('Oblique, World to Image')
set(gca,'xLim',[0 720],'yLim',[0 480],'yDir','Reverse')

subplot(2,2,3)
plot(x_nadir_0,y_nadir_0,'-k')
hold('on')
plot(x_nadir_roll,y_nadir_roll,'-r')
plot(x_nadir_pitch,y_nadir_pitch,'-b')
plot(x_nadir_azimuth,y_nadir_azimuth,'-g')
hold('off')
xlabel('x [m]'), ylabel('y [m]')
title('Nadir, Image to World')
set(gca,'xLim',[-10 10],'yLim',[-10 10],'yDir','Normal')

subplot(2,2,4)
plot(x_oblique_0,y_oblique_0,'-k')
hold('on')
plot(x_oblique_roll,y_oblique_roll,'-r')
plot(x_oblique_pitch,y_oblique_pitch,'-b')
plot(x_oblique_azimuth,y_oblique_azimuth,'-g')
hold('off')
xlabel('x [m]'), ylabel('y [m]')
title('Oblique, Image to World')
set(gca,'xLim',[-10 10],'yLim',[0 20],'yDir','Normal')

print(gcf,'/Users/mike/Downloads/AzimuthFixedPlots.png','-dpng')