function [Products] = define_xtransect(origin_grid)
    Product = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[]);
    %Products = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[]);

    Product.productType = 'Timestack';
    Product.type = 'xTransect';
    Product.lat = origin_grid(1);
    Product.lon = origin_grid(2);
    Product.angle = origin_grid(3);


    info = inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (+m from Origin)', 'Onshore cross-shore extent (+m from Origin)', ...
                     'Alongshore location of transects (m from Origin, looking offshore, right side +) - e.g. -100, 0, 100 OR [-100:100:100]',...
                     'dx', 'z elevation (tide level in relevant datum)'});
    
    answer = questdlg('Do you want to include a DEM?', 'DEM file', 'Yes', 'No', 'Yes');
        
    % check that there's a value in all the required fields
    if ~isempty(find(isnan(double(string(info([1 2 3 5]))))))
        disp('Please fill out all boxes (except z elevation if necessary)')
        info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                     'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]',...
                     'dx', 'z elevation (tide level in relevant datum)'})));
    end

    info_num = abs(double(string(info([1 2 3 5 6])))); % making everything +meters from origin

    if info_num(1) > 30
        disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
        info_num(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
    end
    Product.frameRate = info_num(1);
    Product.xlim = [-info_num(2) info_num(3)]; % offshore limit is negative meters
    Product.dx = info_num(4);

    yy = string(info(4));
    if contains(yy, ',')
        yy = double(split(yy, ','));
    elseif contains(yy, ':')
        eval(['yy= ' char(yy)]);
    else
        disp('Please input in the correct format (comma-separated list or [ylim1:dy:ylim2])')
        yy = string(inputdlg({'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]'}));
    end

    switch answer
        case 'No'
            Z = repmat(info_num(5), length(yy),1);
        case 'Yes'
        X_line = -[Product.xlim(1):Product.dx:Product.xlim(2)];
        Y_line = [yy];
        [X,Y] = meshgrid(X_line,Y_line);
                
        disp('Load in DEM file')
        [temp_file, temp_file_path] = uigetfile(pwd, 'DEM file');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*
        answer2 = questdlg('Is this a global DEM file or local?', 'DEM file', 'Global', 'Local', 'Local');
        % check that local coordinates
        %DEM_scale = (floor(log(abs([DEM.y]))./log(10))); DEM_scale(isinf(DEM_scale)) = []; DEM_scale = nanmean(DEM_scale)
        %grid_scale =(floor(log(abs([yy]))./log(10))); grid_scale(isinf(grid_scale)) = []; grid_scale = nanmean(grid_scale)
        %if DEM_scale ~= grid_scale
        %    answer2 = 'Global';
        %end
        switch answer2
            case 'Global' % assumes DEM in UTM coordinates
                [origin_grid(1), origin_grid(2), ~] = ll_to_utm(origin_grid(1), origin_grid(2));
                
                for ii = 1:length(DEM)
                    % Translate from origin
                    ep=DEM(ii).x-origin_grid(1);
                    np=DEM(ii).y-origin_grid(2);
                    
                    % Rotation
                    DEM(ii).x=ep.*cosd(origin_grid(3))+np.*sind(origin_grid(3));
                    DEM(ii).y=np.*cosd(origin_grid(3))-ep.*sind(origin_grid(3));

                    Z_line(ii,:) = interp1(DEM(ii).x, DEM(ii).z, X_line);
                end
            case 'Local' % assumes same grid origin and orientation
                for ii = 1:length(DEM)
                    Z_line(ii,:) = interp1(DEM(ii).x, DEM(ii).z, X_line);
                end
        end
        Z = interp2(X_line, [DEM.y], Z_line, X, Y);
        tide_level = info_num(5)*ones(size(X,1), size(X,2));
        aa(:,:,1)=Z;
        aa(:,:,2)=tide_level;
        Z = max(aa,[],3);
        
    end

    for ii = 1:length(yy)
            Products(ii) = Product;
            Products(ii).y = yy(ii);
            Products(ii).z = Z(ii,:);
     end

end