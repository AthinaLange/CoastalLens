function [Products] = define_xtransect(origin_grid)
%   define_xtransect returns structure with dimensions needed for a  cross-shore transect (timestack).
%% Syntax
% [Products] = define_xtransect([lat lon angle])
%
%% Description 
% 
%   Args:
%           origin_grid (double) : [1 x 3 array] origin_grid definition [Latitude, Longitude, Angle]
%
%   Returns:
%           Products (structure) : 
%                               - productType : 'Timestack'
%                               - type : 'xTransect'
%                               - frameRate : frame rate to process data (Hz)
%                               - lat : latitude of origin grid
%                               - lon: longitude of origin grid
%                               - angle: shorenormal angle of origid grid
%                               - xlim : cross-shore limits of grid (pos is offshore of origin) (m)
%                               - dx : Cross-shore resolution (m)
%                               - y : Along-shore distance from origin (pos is to the right of the origin looking offshore) (m)
%                               - z : Elevation - can be empty or array of DEM values (NAVD88 m)
%               
% Angle: Shorenormal angle of the locally defined grid (CW from North)
%
%% Citation Info 
% github.com/AthinaLange/CoastalLens
% Nov 2023; 

%%
assert(isa(origin_grid, 'double'), 'Error (define_xtransect): origin_grid must be an array of doubles.')
assert(length(origin_grid)==3, 'Error (define_xtransect): origin_grid must contain 3 values.')
%%
Product = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[], 'tide', []);

Product.productType = 'Timestack';
Product.type = 'xTransect';
Product.lat = origin_grid(1);
Product.lon = origin_grid(2);
Product.angle = origin_grid(3);

info = inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (+m from Origin)', 'Onshore cross-shore extent (m from Origin, + is offshore)', ...
    'Alongshore location of transects (m from Origin, looking offshore, right side +) - e.g. -100, 0, 100 OR [-100:100:100]',...
    'dx (Cross-shore Resolution m)'}, 'xTransect Coordinates');

% check that there's a value in all the required fields
if ~isempty(find(isnan(double(string(info([1 2 3 5])))), 1))
    disp('Please fill out all boxes (except z elevation if necessary)')
    info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin, + is offshore)', ...
        'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]',...
        'dx (Cross-shore Resolution m)'}, 'xTransect Coordinates')));
end % if ~isempty(find(isnan(double(string(info([1 2 3 5]))))))

info_num = double(string(info([1 2 3 5]))); 

if info_num(1) > 30
    disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
    info_num(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
end % if info_num(1) > 30
Product.frameRate = abs(info_num(1));
Product.xlim = [info_num(2) info_num(3)]; % offshore limit is negative meters
Product.dx = abs(info_num(4));

yy = string(info(4));
if contains(yy, ',')
    yy = double(split(yy, ','));
elseif contains(yy, ':')
    eval(['yy= ' char(yy) ';']);
elseif length(yy) == 1
    yy=double(yy);
 else
    disp('Please input in the correct format (comma-separated list or [ylim1:dy:ylim2])')
    yy = string(inputdlg({'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]'}));
end % if contains(yy, ',')

for ii = 1:length(yy)
    Products(ii) = Product;
    Products(ii).y = yy(ii);
end % for ii = 1:length(yy)

end