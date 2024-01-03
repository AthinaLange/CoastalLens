
%% Define product type

Products = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[]);

answer2 = questdlg('Do you have a .mat origin file?', 'Grid file', 'Yes', 'No', 'Yes');
switch answer2
    case 'Yes'
        [temp_file, temp_file_path] = uigetfile(global_dir, 'Grid file');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*
        if abs(origin_grid(1)) < 90
            Product_base.lat = origin_grid(1);
        else
            Product_base.lat = double(string(inputdlg('Latitude of Origin')));
        end

        if abs(origin_grid(2)) < 180
            Product_base.lon = origin_grid(2);
        else
            Product_base.lon = double(string(inputdlg('Longitude of Origin')));
        end

        if origin_grid(3) < 360 && origin_grid(3) > 0 
            Product_base.angle = origin_grid(3);
        else
            Product_base.angle = double(string(inputdlg('Angle (CC degrees from North)')));
        end

    case 'No'
        origin_grid = inputdlg({'Latitude of Origin', 'Longitude of Origin', 'Angle (CC degrees from North)'});
        origin_grid = double(string(origin_grid));
        if abs(origin_grid(1)) < 90
            Product_base.lat = origin_grid(1);
        else
            Product_base.lat = double(string(inputdlg('Latitude of Origin')));
        end

        if abs(origin_grid(2)) < 180
            Product_base.lon = origin_grid(2);
        else
            Product_base.lon = double(string(inputdlg('Longitude of Origin')));
        end

        if origin_grid(3) < 360 && origin_grid(3) > 0 
            Product_base.angle = origin_grid(3);
        else
            Product_base.angle = double(string(inputdlg('Angle (CC degrees from North)')));
        end
end % answer2

origin_grid = [Product_base.lat Product_base.lon Product_base.angle];


productFlag = 0;
productCounter = 0;

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
   
       Products(productCounter:productCounter+length(Product1))=Product1;
       
        productCounter = length(Products);

    % ===========================================================================
    % ============================== yTransect ==================================
    % ===========================================================================
    elseif productType_ind == 3
        [Product1] = define_ytransect(origin_grid);
    
        Products(productCounter:productCounter+length(Product1))=Product1;

        productCounter = length(Products);
    end % productType
   
    answer2 = questdlg('Define more products?', 'Do you want to create more products?', 'Yes', 'No', 'Yes');
    switch answer2
        case 'No'
            productFlag = 1;
    end 
end % while productFlag = 0
Products(1:length(Products)).lat = Product_base.lat;
Products(1:length(Products)).lon = Product_base.lon;
Products(1:length(Products)).angle = Product_base.angle;
