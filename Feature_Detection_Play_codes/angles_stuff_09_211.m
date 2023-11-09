%uiopen('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/undistortImage.png',1)
[m,n,c] = size(undistortImage); % image dimensions for edge coordinates

load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/input_data.mat', 'origin_grid')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/Inital_coordinates.mat', 'extrinsicsInitialGuess')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IOEOInitial.mat', 'intrinsics')
[y2,x2, ~] = ll_to_utm(origin_grid(1), origin_grid(2));


 extrinsicsInitialGuess(1)=extrinsicsInitialGuess(1)-8;
 extrinsicsInitialGuess(3)=70;
 extrinsicsInitialGuess(4)=deg2rad(270);

i_bounds = [0 .1*m; n .1*m; n m; 0 m];

[w_bounds] = distUV2XYZ(intrinsics, extrinsicsInitialGuess, i_bounds', 'z', zeros(1, size(i_bounds,1)))

[wX,wY]=meshgrid([min(w_bounds(:,1)):1:max(w_bounds(:,1))],[min(w_bounds(:,2)):1:max(w_bounds(:,2))]);

[Ir]= imageRectifier(undistortImage, intrinsics, extrinsicsInitialGuess,wX, wY, zeros(size(wX,1), size(wX,2)), 0);

%% 
google_earth = flipud(imread(['~/Desktop/TP.jpg']));

[a,b,~] = size(google_earth);
ge_coord = [3643840.68 475069.92;...
                    3643860.25 475983.53;...
                    3642800.99 475979.92;...
                    3642779.40 475119.12];

aa=linspace(3642800, 3643800, a);
bb=linspace(475075, 475980, b);
[ge_x, ge_y]=meshgrid(bb,aa); 

 [UVd,flag] = xyz2DistUV(intrinsics,extrinsicsInitialGuess,[x2 y2 0])

 [xyz]=distUV2XYZ(intrinsics, extrinsicsInitialGuess, [UVd'; n m]', 'z', [0 0])
%%
figure(2);clf
imagesc(ge_x(:), ge_y(:), google_earth)
hold on
scatter(x2,y2, 100, 'r', 'filled')
scatter(xyz(:,1), xyz(:,2), 'g', 'filled')
scatter(w_bounds(:,1), w_bounds(:,2), 50, colors(1:4,:), 'filled')
patch(w_bounds(1:4,1), w_bounds(1:4,2), 'r', 'FaceColor', 'none')
set(gca, 'YDir', 'normal')
%image(wX(:), wY(:), Ir, 'AlphaData', 0.8)
scatter3(Points(:,1), Points(:,2), Points(:,3)-5, 50, cPoints, 'filled')

figure(3);clf
image(undistortImage)
hold on
scatter(UVd(1), UVd(2), 'r', 'filled')
scatter(n,m, 'r', 'filled')
xlim([-1 n+1])
ylim([-1 m+1])


%%

%get_local_survey
Points = pc.Location;
if ~isempty(pc.Color)
    cPoints = pc.Color;
    if contains(class(cPoints), 'uint16')
        cPoints = double(cPoints) / 65535;
    end
else
    cPoints = Points(:,3);
end

[in,on] = inpolygon(Points(:,1), Points(:,2),[w_bounds(1:4,1); w_bounds(1,1)], [w_bounds(1:4,2); w_bounds(1,2)]);
Points = Points(in,:);
cPoints = cPoints(in,:);

%%
figure(1);clf
subplot(121)
scatter3(extrinsicsInitialGuess(1), extrinsicsInitialGuess(2), extrinsicsInitialGuess(3), 100, 'r','filled')
hold on
image(wX(:), wY(:), Ir)
scatter3(w_bounds(:,1), w_bounds(:,2), w_bounds(:,3), 50, colors(1:length(w_bounds),:), 'filled')
patch(w_bounds(1:4,1), w_bounds(1:4,2), 'r', 'FaceColor', 'none')
%scatter3(Points(:,1), Points(:,2), Points(:,3)-5, 50, cPoints, 'filled')
xlabel('x')
ylabel('y')
% xlim([x2-200 x2+200])
% ylim([y2-200 y2+200])
%xlim([-200 +400])
%ylim([-200 +200])
%zlim([0 7])
set(gca, 'XDir', 'reverse')

subplot(122)
image(undistortImage)
hold on
scatter(i_bounds(:,1), i_bounds(:,2), 50, colors(1:length(i_bounds),:), 'filled')
xlim([-1 n+1])
ylim([-1 m+1])
%axis equal