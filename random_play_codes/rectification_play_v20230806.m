clearvars -except *dir data_files oname Products        
dd=1
load(fullfile(odir, 'Processed_data', 'Inital_coordinates.mat'), 'extrinsicsInitialGuess')
load(fullfile(odir, 'Processed_data', [oname '_IO']), 'intrinsics')
load([data_files(dd).folder '/' data_files(dd).name '/input_data.mat'])
I=imread([odir 'Processed_data/Initial_frame.jpg']);
%%
ids_grid = find(contains(extractfield(Products, 'type'), 'Grid'));
ids_xtransect = find(contains(extractfield(Products, 'type'), 'xTransect'));
ids_ytransect = find(contains(extractfield(Products, 'type'), 'yTransect'));
       
%% GRID
for pp = ids_grid
gridChangeIndex = 0; % check grid
    while gridChangeIndex == 0
        [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
        localExtrinsics = localTransformExtrinsics([x2 y2], -(270-Products(pp).angle), 1, extrinsicsInitialGuess);
        
        if Products(pp).xlim(1) < 0; Products(pp).xlim(1) = -Products(pp).xlim(1); end
        ixlim = x2 - Products(pp).xlim;
        
        if Products(pp).ylim(1) > 0; Products(pp).ylim(1) = -Products(pp).ylim(1); end
        if Products(pp).ylim(2) < 0; Products(pp).ylim(2) = -Products(pp).ylim(2); end
        iylim = y2 + Products(pp).ylim;

        [iX, iY]=meshgrid(ixlim(1):Products(pp).dx:ixlim(2),iylim(1):Products(pp).dy:iylim(2));
        
        % DEM stuff
        if isempty(Products(pp).z); iz=0; else; iz = Products(pp).z; end
        iZ=iX*0+iz;
        
        X=iX; Y=iY; Z=iZ; 
        [localX, localY]=localTransformEquiGrid([x2 y2], 270-Products(pp).angle,1,iX,iY); 
        localZ=localX.*0+iz; 
        
        [Ir]= imageRectifier(I,intrinsics,extrinsicsInitialGuess,X,Y,Z,1);
        subplot(2,2,[2 4])
        title('World Coordinates')
        
        if all([x2 y2] ~= [0,0], 270-Products(pp).angle ~= 0)
            [localIr]= imageRectifier(I,intrinsics,localExtrinsics,localX,localY,localZ,1);
        
            subplot(2,2,[2 4])
            title('Local Coordinates')
            print(gcf,'-dpng',[odir 'Processed_data/' oname '_Grid_Local.png' ])
        else
            print(gcf,'-dpng',[odir 'Processed_data/' oname '_Grid_World.png' ])
        end

        answer = questdlg('Happy with rough grid projection?', ...
             'Rough grid projection',...
             'Yes', 'No', 'Yes');

        switch answer
            case 'Yes'
                gridChangeIndex = 1;
            case 'No'
               disp('Please change grid.')
               info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                             'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
                             'dx', 'dy', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'})));
                
               info = abs(info); % making everything +meters from origin
            
                % check that there's a value in all the required fields
                if find(isnan(info)) ~= 8
                    disp('Please fill out all boxes (except z elevation if necessary)')
                    info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                                 'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
                                 'dx', 'dy', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'})));
                    info = abs(info); % making everything +meters from origin
                end
                
                if info(1) > 30
                    disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
                    info(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
                end
                Products(pp).frameRate = info(1);
    
                Products(pp).xlim = [info(2) -info(3)]; % offshore limit is negative meters
                if Products(pp).angle < 180 % East Coast
                    Products(pp).ylim = [-info(5) info(4)]; % -north +south
                elseif Products(pp).angle > 180 % West Coast
                    Products(pp).ylim = [-info(4) info(5)]; % -south +north
                end
                Products(pp).dx = info(6);
                Products(pp).dy = info(7);
                if ~isnan(info(8))
                    Products(pp).z = info(8);
                else
                    % PULL IN DEM
                end
        end % check answer
    end % check gridCheckIndex
end % for pp = 1:length(ids_grid)

%% xTRANSECT
figure
hold on
imshow(I)
hold on
title('Timestack')
for pp = ids_xtransect
    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    
    if Products(pp).xlim(1) < 0; Products(pp).xlim(1) = -Products(pp).xlim(1); end
    ixlim = x2 - Products(pp).xlim;
    iy = y2 + Products(pp).y;

    X = [ixlim(1):Products(pp).dx:ixlim(2)]';
    Y = X.*0+iy;
    Z = X.*0;
    xyz = cat(2,X(:), Y(:), Z(:));

    [UVd] = xyz2DistUV(intrinsics, extrinsicsInitialGuess,xyz);
        
    UVd = reshape(UVd,[],2);
    plot(UVd(:,1),UVd(:,2),'*')
    xlim([0 intrinsics(1)])
    ylim([0  intrinsics(2)])

    le{pp}= [Products(pp).type ' - y = ' char(string(Products(pp).y)) 'm'];
   
end % for pp = 1:length(ids_xtransect)
legend(le)
%% 
%% yTRANSECT - NEED TO CHECK
figure
hold on
imshow(I)
hold on
title('yTransect')
for pp = ids_xtransect
    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    
    if Products(pp).ylim(1) > 0; Products(pp).ylim(1) = -Products(pp).ylim(1); end
    if Products(pp).ylim(2) < 0; Products(pp).ylim(2) = -Products(pp).ylim(2); end
    iylim = y2 + Products(pp).ylim;

    ix = x2 + Products(pp).x;

    Y = [iylim(1):Products(pp).dy:iylim(2)]';
    X = Y.*0+ix;
    Z = Y.*0;
    xyz = cat(2,X(:), Y(:), Z(:));

    [UVd] = xyz2DistUV(intrinsics, extrinsicsInitialGuess,xyz);
        
    UVd = reshape(UVd,[],2);
    plot(UVd(:,1),UVd(:,2),'*')
    xlim([0 intrinsics(1)])
    ylim([0  intrinsics(2)])

    le{pp}= [Products(pp).type ' - x = ' char(string(Products(pp).x)) 'm'];
   
end % for pp = 1:length(ids_xtransect)
legend(le)
   