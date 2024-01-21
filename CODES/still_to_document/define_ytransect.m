function [Products] = define_ytransect(origin_grid)
Product = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[]);

Product.productType = 'yTransect';
Product.type = 'yTransect';
Product.lat = origin_grid(1);
Product.lon = origin_grid(2);
Product.angle = origin_grid(3);

info = inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
    'Alongshore location of transects (m from Origin) - e.g. 50, 100, 200 OR [50:50:200]',...
    'dx', 'z elevation (tide level in relevant datum - or elevation if on beach)'});

% check that there's a value in all the required fields
if ~isempty(find(isnan(double(string(info([1 2 4]))))))
    disp('Please fill out all boxes (except z elevation if necessary)')
    info = double(string(inputdlg({'Frame Rate (Hz)', 'Southern alongshore extent (m from Origin)', 'Northern alongshore extent (m from Origin)', ...
        'Cross-shore location of transects (m from Origin) - e.g. 50, 100, 200 OR [50:50:200]',...
        'dy', 'z elevation (tide level in relevant datum - or elevation if on beach)'})));
end

info_num = abs(double(string(info([1 2 3 5 6])))); % making everything +meters from origin

if info_num(1) > 30
    disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
    info_num(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
end
Product.frameRate = info_num(1);

if Product.angle < 180 % East Coast
    Product.ylim = [-info_num(3) info_num(2)]; % -north +south
elseif Product.angle > 180 % West Coast
    Product.ylim = [-info_num(2) info_num(3)]; % -south +north
end
Product.dy = info_num(4);

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
    Product.z = info_num(5);
else
    Product.z = 0;
end


for ii = 1:length(xx)
    Products(ii) = Product;
    Products(ii).x = xx(ii);
end

end