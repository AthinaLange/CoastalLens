
L = dir('images_10Hz'); L([L.isdir] == 1) = []; if ~isempty(L); L = string(extractfield(L, 'name')');end;  if ~isempty(L); L(L=='.DS_Store')=[];end
               
%%
tic
for ll = 1:5%length(L)
    clearvars -except L ll sky water horizon_line cameraParams extrinsics intrinsics
    I=imread(fullfile('images_10Hz', L(ll)));
    I= undistortImage(I, cameraParams);
    
    if ll == 1
        % figure(1);clf
        % imshow(I)
        % title('Please click first on a sky point, then on a water point. - Click outside of image if no horizon.')
        % 
        % a = drawpoint();
        % if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1)) 
        %     break;  % Exit the loop when Enter is pressed
        % else
        %     sky = round(a.Position);
        % end
        % drawpoint('Position', sky, 'Label', ['Sky Point']);
        % 
        % b=drawpoint();
        % water = round(b.Position);
        % drawpoint('Position', water, 'Label', ['Water Point']);

        
        slprojd=200; % Shoreline Projection Distance
        worldR=7/6*6378*1000; % World Radius in Meters
        
        Horizon.R=worldR; 
        Horizon.h=extrinsics(3);
        Horizon.d=sqrt(2*Horizon.R*Horizon.h+Horizon.h^2);
        Horizon.deg=0;
        Horizon.eutm=extrinsics(1)+cos(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
        Horizon.nutm=extrinsics(2)+sin(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
        Horizon.zh=0; % should be tide
        [UVd,flag] = xyz2DistUV(intrinsics,extrinsics,[Horizon.eutm' Horizon.nutm' Horizon.zh']);
        sky = round([UVd(1) UVd(2)/2]);
        water = round([UVd(1) UVd(2)+UVd(2)/2]);
        figure(1);clf
        imshow(I)
        hold on
        drawpoint('Position', sky, 'Label', ['Sky Point']);
        drawpoint('Position', water, 'Label', ['Water Point']);
       
    end
    
    [horizon_line(ll,:)] = get_horizon(I, sky, water);


     x = [0 size(I,2)];
     y = horizon_line(ll,1)*x + horizon_line(ll,2);
    
    if rem(ll,1)==0
        ll
        figure(ll);clf
        imshow(I)
        hold on
        plot(x,y,'g-')
        scatter(sky(1), sky(2), 50,'r','filled')
        scatter(water(1), water(2) , 50,'b','filled')
        toc
    end

    perc_20 = min(y)/5;
    sky =  round([mean(x) min(y) - perc_20]);
    water = round([mean(x) max(y) + perc_20]);
end
toc