function [Products] = user_input_products(global_dir)
% user_input_products returns structure with dimensions needed to construct cBathy-type grids, cross-shore and along-shore transects.
%% Syntax
%           [Products] = user_input_products(global_dir)
%
%% Description
%   Args:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%
%   Returns:
%           Products (structure) :
%                               - productType : 'cBathy', 'Timestack', 'yTransect'
%                               - type : 'Grid', 'xTransect', 'yTransect'
%                               - frameRate : frame rate to process data (Hz)
%                               - lat : latitude of origin grid
%                               - lon: longitude of origin grid
%                               - angle: shorenormal angle of origid grid
%                               - xlim : cross-shore limits of grid (+ is offshore of origin) (m)
%                               - ylim : along-shore limits of grid (+ is to the right of origin looking offshore) (m)
%                               - dx : Cross-shore resolution (m)
%                               - dy : Along-shore resolution (m)
%                               - x : Cross-shore distance from origin (+ is offshore of origin) (m)
%                               - y : Along-shore distance from origin (+ is to the right of the origin looking offshore) (m)
%                               - z : Elevation - can be empty, assigned to tide level, or array of DEM values (NAVD88 m)
%
% Angle: Shorenormal angle of the locally defined grid (CW from North)
%
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Sept 2023;

%% ===============ORIGIN FILE=====================================================
%                           - Check if user already has origin file for given location
%                           - Check that Lat / Lon / Angle correct order of magnitude - otherwise fill in again
%  =====================================================================
Product_base = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[]);

% check if origin file exists or input data
answer2 = questdlg('Do you have a .mat origin file?', 'Grid file', 'Yes', 'No', 'Yes');
switch answer2
    case 'Yes'
        disp('Please load in origin grid file.')
        disp('For DEMO: under demo_files/origin_Torrey.mat')
        [temp_file, temp_file_path] = uigetfile(global_dir, 'Origin grid file');
        load(fullfile(temp_file_path, temp_file), 'origin_grid'); clear temp_file*
        if length(origin_grid) ~= 3
            origin_grid = inputdlg({'Latitude of Origin', 'Longitude of Origin', 'Angle (CC degrees from North)'});
            origin_grid = double(string(origin_grid));
        end
    case 'No'
        origin_grid = inputdlg({'Latitude of Origin', 'Longitude of Origin', 'Angle (CC degrees from North)'});
        origin_grid = double(string(origin_grid));
end % switch answer2

% Check latitude
if abs(origin_grid(1)) < 90
    Product_base.lat = origin_grid(1);
else
    Product_base.lat = double(string(inputdlg('Latitude of Origin')));
end % if abs(origin_grid(1)) < 90

% Check longitude
if abs(origin_grid(2)) < 180
    Product_base.lon = origin_grid(2);
else
    Product_base.lon = double(string(inputdlg('Longitude of Origin')));
end % if abs(origin_grid(2)) < 180

% Check angle
if origin_grid(3) < 360 && origin_grid(3) > 0
    Product_base.angle = origin_grid(3);
else
    Product_base.angle = double(string(inputdlg('Angle (CC degrees from North)')));
end % if origin_grid(3) < 360 && origin_grid(3) > 0
origin_grid = [Product_base.lat Product_base.lon Product_base.angle];

productFlag = 0;
productCounter = 0;

%% ===============PRODUCT INFO====================================================
%                           - GRID (cBathy)
%                                   - Frame Rate
%                                   - Cross-shore extent (Offshore and Onshore in m from origin)
%                                   - Alongshore extent (Southern and Northern edge in m from origin) - flips based on grid angle
%                                   - dx, dy
%                                   - z elevation
%                           - xTransect (Timestack)
%                                   - Frame Rate
%                                   - Cross-shore extent (Offshore and Onshore in m from origin)
%                                   - Alongshore locations of transets (in m from origin) - e.g. -100, 0, 100 OR [-100:100:100]
%                                   - dx
%                                   - z elevation
%                           - yTransect
%                                   - Frame Rate
%                                   - Alongshore extent (Southern and Northern edge in m from origin)
%                                   - Cross-shore locations of transets (in m from origin) - e.g. 50, 100, 200 OR [50:50:200]
%                                   - dy
%                                   - z elevation
%  =====================================================================
while productFlag == 0
    clear productType Product1 info yy xx info_num
    productCounter = productCounter + 1;
    [productType_ind,~] = listdlg('ListString',{'Grid (cBathy/Rectified Image)', 'xTransect (Timestack)', 'yTransect'}, 'SelectionMode','single', 'InitialValue',1, 'Name', 'What product do you want to create?', 'ListSize', [500 300]);

    % ============================== GRID =======================================
    if productType_ind == 1
        [Product1] = define_grid(origin_grid);
        Products(productCounter) = Product1;
        % ============================== xTransect ==================================
    elseif productType_ind == 2
        [Product1] = define_xtransect(origin_grid);
        for ii = 1:length(Product1)
            Products(productCounter+ii-1)=Product1(ii);
        end % for ii = 1:length(Product1)
        productCounter = length(Products);
        % ============================== yTransect ==================================
    elseif productType_ind == 3
        [Product1] = define_ytransect(origin_grid);
        for ii = 1:length(Product1)
            Products(productCounter+ii-1)=Product1(ii);
        end % for ii = 1:length(Product1)
        productCounter = length(Products);
    end %  if productType_ind == 1

    answer2 = questdlg('Do you want to create more products?', 'Define more products?', 'Yes', 'No', 'Yes');
    switch answer2
        case 'No'
            productFlag = 1;
    end %  switch answer2
end % while productFlag == 0


answer4 = questdlg('Do you want to save this product file for the future?', 'Save Products file', 'Yes', 'No', 'Yes');
switch answer4
    case 'Yes'
        info = inputdlg({'Filename to be saved'});
        disp('Location where Products file to be saved.')
        temp_file_path = uigetdir(global_dir, 'Products file save location');
        [Products.z] = deal([]);
        save(fullfile(temp_file_path, [info{1} '.mat']), 'Products', 'origin_grid')
end % switch answer4
