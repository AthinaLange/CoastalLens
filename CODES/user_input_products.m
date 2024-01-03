%% user_input_products
% gets all required product data for UAV_automated_rectification toolbox
%
% - Define origin of grid
% - Define products - grid, xTransect, yTransect
%
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
origin_grid = [Product_base.lat Product_base.lon Product_base.angle];

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

    [productType_ind,tf] = listdlg('ListString',{'Grid (cBathy)', 'xTransect (Timestack)', 'yTransect', 'Other (Not recommended)'}, 'SelectionMode','single', 'InitialValue',[1], 'Name', 'What product do you want to create?');
    
    % ===========================================================================
    % ============================== GRID =======================================
    % ===========================================================================
    if productType_ind == 1
        [Product1] = define_grid(origin_grid);

        Products(productCounter) = Product1;
       
    % ===========================================================================
    % ============================== xTransect ==================================
    % ===========================================================================
    elseif productType_ind == 2
        [Product1] = define_xtransect(origin_grid);
   
        for ii = 1:length(Product1)
            Products(productCounter+ii-1)=Product1(ii);
        end
       
        productCounter = length(Products);

    % ===========================================================================
    % ============================== yTransect ==================================
    % ===========================================================================
    elseif productType_ind == 3
        [Product1] = define_ytransect(origin_grid);
    
        for ii = 1:length(Product1)
            Products(productCounter+ii-1)=Product1(ii);
        end

        productCounter = length(Products);
    end % productType
   
    answer2 = questdlg('Define more products?', 'Do you want to create more products?', 'Yes', 'No', 'Yes');
    switch answer2
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
    