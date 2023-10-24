%% user_input_products
% gets all required product data for UAV_automated_rectification toolbox
%
% - Define origin of grid
% - Define products - grid, xTransect, yTransect
%
% TODO add in additional product options
% TODO incorporate DEM into grid
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%% ====================================================================
%                          ORIGIN FILE        
%                           - Check if user already has origin file for given location
%                           - Check that Lat / Lon / Angle correct order of magnitude - otherwise fill in again
%  =====================================================================
Product_base = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[]);

% check if origin file exists or input data
answer2 = questdlg('Do you have a .mat origin file?', 'Grid file', 'Yes', 'No', 'Yes');
switch answer2
    case 'Yes'
        disp('Please load in origin grid file.')
        disp('For CPG: under CPG_data/origin_Torrey.mat') %% XXX
        [temp_file, temp_file_path] = uigetfile(global_dir, 'Origin grid file');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*
    case 'No'
        origin_grid = inputdlg({'Latitude of Origin', 'Longitude of Origin', 'Angle (CC degrees from North)'});
        origin_grid = double(string(origin_grid));
end

% Check latitude
if abs(origin_grid(1)) < 90
    Product_base.lat = origin_grid(1);
else
    Product_base.lat = double(string(inputdlg('Latitude of Origin')));
end
% Check longitude
if abs(origin_grid(2)) < 180
    Product_base.lon = origin_grid(2);
else
    Product_base.lon = double(string(inputdlg('Longitude of Origin')));
end
% Check angle
if origin_grid(3) < 360 && origin_grid(3) > 0 
    Product_base.angle = origin_grid(3);
else
    Product_base.angle = double(string(inputdlg('Angle (CC degrees from North)')));
end

productFlag = 0;
productCounter = 0;

%% ====================================================================
%                         PRODUCT INFO        
%                           - GRID (cBathy)
%                                   - Frame Rate
%                                   - Cross-shore extent (Offshore and Onshore in m from origin)
%                                   - Alongshore extent (Southern and Northern edge in m from origin) - flips based on grid angle
%                                   - dx, dy
%                                   - z elevation - TODO add DEM
%                           - xTransect (Timestack)
%                                   - Frame Rate
%                                   - Cross-shore extent (Offshore and Onshore in m from origin)
%                                   - Alongshore locations of transets (in m from origin) - e.g. -100, 0, 100 OR [-100:100:100]
%                                   - dx
%                                   - z elevation - TODO add DEM
%                           - yTransect
%                                   - Frame Rate
%                                   - Alongshore extent (Southern and Northern edge in m from origin)
%                                   - Cross-shore locations of transets (in m from origin) - e.g. 50, 100, 200 OR [50:50:200]
%                                   - dy
%                                   - z elevation - TODO add DEM
%  =====================================================================
while productFlag == 0
    clear productType Product1 info yy xx info_num
    productCounter = productCounter + 1;
    Product1 = Product_base;

    [productType_ind,tf] = listdlg('ListString',{'Grid (cBathy)', 'xTransect (Timestack)', 'yTransect', 'Other (Not recommended)'}, 'SelectionMode','single', 'InitialValue',[1], 'Name', 'What product do you want to create?');
    
    % ===========================================================================
    % ============================== GRID =======================================
    % ===========================================================================
    if productType_ind == 1
        Product1.productType = 'cBathy';
        Product1.type = 'Grid';
        info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                         'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
                         'dx', 'dy', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type)));
            
        info = abs(info); % making everything +meters from origin
        
        % check that there's a value in all the required fields
        if find(isnan(info)) ~= 8
            disp('Please fill out all boxes (except z elevation if necessary)')
            info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                         'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
                         'dx', 'dy', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type)));
            info = abs(info); % making everything +meters from origin
        end
            
        if info(1) > 30
            disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
            info(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
        end
        Product1.frameRate = info(1);

        Product1.xlim = [info(2) -info(3)]; % offshore limit is negative meters
        if Product1.angle < 180 % East Coast
            Product1.ylim = [-info(5) info(4)]; % -north +south
        elseif Product1.angle > 180 % West Coast
            Product1.ylim = [-info(4) info(5)]; % -south +north
        end
        Product1.dx = info(6);
        Product1.dy = info(7);
        if ~isnan(info(8))
            Product1.z = info(8);
        else
            % PULL IN DEM
        end

        Products(productCounter) = Product1;

    % ===========================================================================
    % ============================== xTransect ==================================
    % ===========================================================================
    elseif productType_ind == 2
        Product1.productType = 'Timestack';
        Product1.type = 'xTransect';
    
        info = inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                         'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]',...
                         'dx', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type);
            
        % check that there's a value in all the required fields
        if ~isempty(find(isnan(double(string(info([1 2 3 5]))))))
            disp('Please fill out all boxes (except z elevation if necessary)')
            info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                         'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]',...
                         'dx', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type)));
        end
    
        info_num = abs(double(string(info([1 2 3 5 6])))); % making everything +meters from origin

        if info_num(1) > 30
            disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
            info_num(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
        end
        Product1.frameRate = info_num(1);
        Product1.xlim = [-info_num(2) info_num(3)]; % offshore limit is negative meters
        Product1.dx = info_num(4);
    
        yy = string(info(4));
        if contains(yy, ',')
            yy = double(split(yy, ','));
        elseif contains(yy, ':')
            eval(['yy= ' char(yy)]);
        else
            disp('Please input in the correct format (comma-separated list or [ylim1:dy:ylim2])')
            yy = string(inputdlg({'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]'}));
        end
    
        if ~isnan(info_num(5))
            Product1.z = info_num(5);
        else
            % PULL IN DEM
        end
    
        for ii = 1:length(yy)
            Product1.y = yy(ii);
            Products(productCounter + ii - 1) = Product1;
        end
        productCounter = length(Products);
    
    
    % ===========================================================================
    % ============================== yTransect ==================================
    % ===========================================================================
    elseif productType_ind == 3
        Product1.productType = 'yTransect';
        Product1.type = 'yTransect';
    
        info = inputdlg({'Frame Rate (Hz)', 'Southern alongshore extent (m from Origin)', 'Northern alongshore extent (m from Origin)', ...
                         'Cross-shore location of transects (m from Origin) - e.g. 50, 100, 200 OR [50:50:200]',...
                         'dx', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type);
            
        % check that there's a value in all the required fields
        if ~isempty(find(isnan(double(string(info([1 2 4]))))))
            disp('Please fill out all boxes (except z elevation if necessary)')
            info = double(string(inputdlg({'Frame Rate (Hz)', 'Southern alongshore extent (m from Origin)', 'Northern alongshore extent (m from Origin)', ...
                         'Cross-shore location of transects (m from Origin) - e.g. 50, 100, 200 OR [50:50:200]',...
                         'dy', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type)));
        end
    
        info_num = abs(double(string(info([1 2 3 5 6])))); % making everything +meters from origin
    
        if info_num(1) > 30
            disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
            info_num(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
        end
        Product1.frameRate = info_num(1);

        if Product1.angle < 180 % East Coast
            Product1.ylim = [-info_num(3) info_num(2)]; % -north +south
        elseif Product1.angle > 180 % West Coast
            Product1.ylim = [-info_num(2) info_num(3)]; % -south +north
        end
        Product1.dy = info_num(4);
    
        xx = string(info(4));
        if contains(xx, ',')
            xx = double(split(xx, ','));
        elseif contains(xx, ':')
            eval(['xx= ' char(xx)]);
        else
            disp('Please input in the correct format (comma-separated list or [ylim1:dy:ylim2])')
            xx = string(inputdlg({'Cross-shore location of transects (m from Origin) - e.g. 50, 100, 200 OR [50:50:200]'}));
        end
    
        if ~isnan(info_num(5))
            Product1.z = info_num(5);
        else
            % PULL IN DEM
        end
    
        for ii = 1:length(xx)
            Products(productCounter + ii - 1) = Product1;
            Products(productCounter + ii - 1).x = xx(ii);
        end
        productCounter = length(Products);
    
    % ===========================================================================
    % ============================== Other ======================================
    % ===========================================================================
    else
        Product1.productType = char(string(inputdlg({'Product type name'})));
        disp('Please check which parameters are required.')
        % Product1.x = ;
        % Product1.y = ;
        % Product1.xlim = ;
        % Product1.ylim = ;
        % Product1.dx = ;
        % Product1.dy = ;
        % Product1.z = ;
    end
   
    answer3 = questdlg( 'Do you want to create more products?', 'Define more products?','Yes', 'No', 'Yes');
    switch answer3
        case 'No'
            productFlag = 1;
    end 
end % while productFlag = 0

answer4 = questdlg('Do you want to save this product file for the future?', 'Save Products file', 'Yes', 'No', 'Yes');
switch answer4
    case 'Yes'
        info = inputdlg({'Filename to be saved'});
        disp('Location where Products file to be saved.')
        temp_file_path = uigetdir(global_dir, 'Products file save location');
        save(fullfile(temp_file_path, [info{1} '.mat']), 'Products', 'origin_grid')
end
    