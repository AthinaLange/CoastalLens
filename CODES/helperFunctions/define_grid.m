function [Product] = define_grid(origin_grid)
%   define_grid returns structure with dimensions needed for a cBathy-type grid.
%% Syntax
% [Product] = define_grid([lat lon angle])
%
%% Description 
% 
%   Args:
%           origin_grid (double) : [1 x 3 array] origin_grid definition [Latitude, Longitude, Angle]
%
%   Returns:
%           Products (structure) : 
%                               - productType : 'cBathy'
%                               - type : 'Grid'
%                               - frameRate : frame rate to process data (Hz)
%                               - lat : latitude of origin grid
%                               - lon: longitude of origin grid
%                               - angle: shorenormal angle of origid grid
%                               - xlim : cross-shore limits of grid (pos is offshore of origin) (m)
%                               - ylim : along-shore limits of grid (pos is to the right of origin looking offshore) (m)
%                               - dx : Cross-shore resolution (m)
%                               - dy : Along-shore resolution (m)
%                               - z : Elevation - can be empty or array of DEM values (NAVD88 m)
%               
% Angle: Shorenormal angle of the locally defined grid (CW from North)
%
%% Citation Info 
% github.com/AthinaLange/CoastalLens
% Nov 2023; 

%%
assert(isa(origin_grid, 'double'), 'Error (define_grid): origin_grid must be an array of doubles.')
assert(length(origin_grid)==3, 'Error (define_grid): origin_grid must contain 3 values.')
%%
Product = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[], 'tide', []);

Product.productType = 'cBathy';
Product.type = 'Grid';

Product.lat = origin_grid(1);
Product.lon = origin_grid(2);
Product.angle = origin_grid(3);

info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin, + if offshore)', ...
    'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
    'dx (Cross-shore Resolution m)', 'dy (Along-shore Resolution m)'}, 'Grid Coordinates')));

% check that there's a value in all the required fields
if find(isnan(info)) ~= 7
    disp('Please fill out all boxes (except z elevation if necessary)')
    info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin, + if offshore)', 'Onshore cross-shore extent (m from Origin, + if offshore)', ...
        'Southern Alongshore extent (+m from Origin)', 'Northern Alongshore extent (+m from Origin)',...
        'dx (Cross-shore Resolution m)', 'dy (Along-shore Resolution m)'}, 'Grid Coordinates')));
end % if find(isnan(info)) ~= 7

if info(1) > 30
    disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
    info(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
end % if info(1) > 30
Product.frameRate = abs(info(1));

Product.xlim = [info(2) info(3)]; 
if origin_grid(3) < 180 % East Coast
    Product.ylim = [-info(5) info(4)]; % -north +south
elseif origin_grid(3) > 180 % West Coast
    Product.ylim = [-info(4) info(5)]; % -south +north
end % if origin_grid(3) < 180 % East Coast
Product.dx = abs(info(6));
Product.dy = abs(info(7));

end