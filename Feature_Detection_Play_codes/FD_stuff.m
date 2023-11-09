clear all
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/input_data.mat', 'extract_Hz')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IO.mat', 'cameraParams')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IO.mat', 'intrinsics')
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IOEOInitial.mat', 'extrinsics')

L = dir('images_10Hz'); L([L.isdir] == 1) = []; if ~isempty(L); L = string(extractfield(L, 'name')');end;  if ~isempty(L); L(L=='.DS_Store')=[];end
tic
hh=1
skip_rate = extract_Hz(hh) * 10; % do a every 10sec check on extrinsics
%%
for ll = 1:1:length(L)

    clearvars -except L ll sky water HorizonPts cameraParams extrinsics intrinsics dd *_dir user_email data_files ind_scp_method Ia Points* extract_Hz skip_rate

    if ll == 1
        %% INITAL HORIZON DETECTION
        I = imread(fullfile('images_10Hz', L(ll))); 
        I = undistortImage(I, cameraParams);
    
        % Stuff to do on 1st image - get sky and water point
        Horizon.R=7/6*6378*1000; % World Radius in Meters
        Horizon.h=extrinsics(3);
        Horizon.d=sqrt(2*Horizon.R*Horizon.h+Horizon.h^2);
        Horizon.deg=0;
        Horizon.eutm=extrinsics(1)+cos(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
        Horizon.nutm=extrinsics(2)+sin(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
        Horizon.zh=0; % should be tide %% XXX TBD
        [UVd,flag] = xyz2DistUV(intrinsics,extrinsics,[Horizon.eutm' Horizon.nutm' Horizon.zh']);
        sky = round([UVd(1) UVd(2)/2]);
        water = round([UVd(1) UVd(2)+UVd(2)/2]);

        if any(sky < 0) || any(water < 0)
            figure(1);clf
            imshow(I)
            title('Please click first on a sky point, then on a water point. - Click outside of image if no horizon.')
    
            a = drawpoint();
            if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1)) 
                break;  % Exit the loop when Enter is pressed
            else
                sky = round(a.Position);
            end
            b=drawpoint();
            water = round(b.Position);
        end

        % figure(1);clf
        % imshow(I)
        % hold on
        % drawpoint('Position', sky, 'Label', ['Sky Point']);
        % drawpoint('Position', water, 'Label', ['Water Point']);
       
        [horizon_line(ll,:)] = get_horizon(I, sky, water);
       
          x = [0 size(I,2)/2 size(I,2)];
        HorizonPts(ll,:) = horizon_line(ll,1)*x + horizon_line(ll,2);

         figure(ll);clf
         imshow(I)
         hold on
         plot(x,HorizonPts(ll,:),'g-')
         scatter(sky(1), sky(2), 50,'r','filled')
         scatter(water(1), water(2) , 50,'b','filled')
         title('Initial Horizon Location')
        
        perc_20 = min(HorizonPts(ll,:))/5;
        sky =  round([mean(x) min(HorizonPts(ll,:)) - perc_20]);
        water = round([mean(x) max(HorizonPts(ll,:)) + perc_20]);

        Ia = rgb2gray(I);
        
    else
        %% CONTINUING DETECTION
        I = imread(fullfile('images_10Hz', L(ll)));
        I = undistortImage(I, cameraParams);
    % HORIZON
        % [horizon_line(ll,:)] = get_horizon(I, sky, water);
        % 
        % x = [0 size(I,2)/2 size(I,2)];
        % HorizonPts(ll,:) = horizon_line(ll,1)*x + horizon_line(ll,2);
        % 
        % perc_20 = min(HorizonPts(ll,:))/5;
        % sky =  round([mean(x) min(HorizonPts(ll,:)) - perc_20]);
        % water = round([mean(x) max(HorizonPts(ll,:)) + perc_20]);

    % FEATURES
        Ib = rgb2gray(I);
    
        cutoff = round(size(Ia,1)*(3/4));
        pointsA = detectFASTFeatures(Ia(cutoff:end,:));
        pointsB = detectFASTFeatures(Ib(cutoff:end,:));
        
        [featuresA,pointsA] = extractFeatures(Ia(cutoff:end,:),pointsA);
        [featuresB,pointsB] = extractFeatures(Ib(cutoff:end,:),pointsB);
        indexPairs = matchFeatures(featuresA,featuresB);
        Points(ll).prev = pointsA(indexPairs(:,1),:); Points(ll).prev.Location(:,2) = Points(ll).prev.Location(:,2)+cutoff;
        Points(ll).current = pointsB(indexPairs(:,2),:); Points(ll).current.Location(:,2) = Points(ll).current.Location(:,2)+cutoff;
        if rem(ll-1, skip_rate) == 0
            ll
            Ia_10 = rgb2gray(imread(fullfile('images_10Hz', L(ll-skip_rate))));
            Ia_10 = undistortImage(Ia_10, cameraParams);
        
            cutoff = round(size(Ia_10,1)*(3/4));
            pointsA = detectFASTFeatures(Ia_10(cutoff:end,:));
            pointsB = detectFASTFeatures(Ib(cutoff:end,:));
            
            [featuresA,pointsA] = extractFeatures(Ia_10(cutoff:end,:),pointsA);
            [featuresB,pointsB] = extractFeatures(Ib(cutoff:end,:),pointsB);
            indexPairs = matchFeatures(featuresA,featuresB);
            Points_10(ll).prev = pointsA(indexPairs(:,1),:); Points_10(ll).prev.Location(:,2) = Points_10(ll).prev.Location(:,2)+cutoff;
            Points_10(ll).current = pointsB(indexPairs(:,2),:); Points_10(ll).current.Location(:,2) = Points_10(ll).current.Location(:,2)+cutoff;
    
        end


         % figure(ll);clf
         % subplot(211)
         % imshow(I)
         % hold on
         % plot(x,y,'g-')
         % scatter(sky(1), sky(2), 50,'r','filled')
         % scatter(water(1), water(2) , 50,'b','filled')
         % subplot(212)
         % showMatchedFeatures(Ia_10, Ib, Points_10(ll).prev, Points_10(ll).current)
        %% SET UP FOR NEXT ROUND
        Ia = Ib;

    end % if ll == 1
end % for ll = 1:length(L)
toc
%% Extrinsics Optimization
x = [0 size(I,2)/2 size(I,2)];
clear rOrientation rLocation
for ll =2:length(Points)
     clear E epipolarInliers inlierPoints* F
    [E, epipolarInliers] = estimateEssentialMatrix(...
    Points(ll).prev, Points(ll).current, cameraParams.Intrinsics, Confidence = 99.99);
    %[F, epipolarInliers] = estimateFundamentalMatrix(Points(ll).prev, Points(ll).current)
    % Find epipolar inliers
    inlierPoints1 = Points(ll).prev(epipolarInliers, :);
    inlierPoints2 = Points(ll).current(epipolarInliers, :);
    
    aa = estrelpose(E, cameraParams.Intrinsics, inlierPoints1, inlierPoints2);
    if size(aa) ==[1 1]
       relPose(ll)=aa;
    end
    % [o,l,frac] = relativeCameraPose(E, cameraParams.Intrinsics, inlierPoints1, inlierPoints2);
    % if size(o,3) == 1
    %     rOrientation(ll,:,:) = o;
    %     rLocation(ll,:) = l;
    % else
    %     rOritentation(ll,:,:)=zeros(3);
    %     rLocation(ll,:) = [0 0 0];
    % end
   

end

%%
figure(1);clf
cam = plotCamera(AbsolutePose=relPose(1),Opacity=0)
grid on
xlim([-5 5])
ylim([-5 5])
zlim([-5 5])

%%
XYZ(:,1)=[0 0 0]
for ii = 2:length(relPose)
    if relPose(ii).Translation ~= [0 0 0]
        [XYZ(:,ii)] = transformPointsForward(relPose(ii),XYZ(:,ii-1))
     %  cam.AbsolutePose = rigidtform3d([0 0 0],[x y z])
     %   drawnow();
      %  pause(0.5)
    end
end

%%