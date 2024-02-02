%cd('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01')

L=dir('images_10Hz'); L(1:2)=[];
tic
for ll = 1:100%length(L)
    clearvars -except L ll sky water horizon_line cameraParams
    I=imread(fullfile('images_10Hz', L(ll).name));
    I= undistortImage(I, cameraParams);
    
    if ll == 1
        figure(1);clf
        imshow(I)
        title('Please click first on a sky point, then on a water point. - Click outside of image if no horizon.')
        
        a = drawpoint();
        if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1)) 
            break;  % Exit the loop when Enter is pressed
        else
            sky = round(a.Position);
        end
        drawpoint('Position', sky, 'Label', 'Sky Point');
        
        b=drawpoint();
        water = round(b.Position);
        drawpoint('Position', water, 'Label', 'Water Point');
       
    end
    
    [horizon_line(ll,:)] = get_horizon(I, sky, water);


     x = [0 size(I,2)];
     y = horizon_line(ll,1)*x + horizon_line(ll,2);
    
    if rem(ll,100)==0
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