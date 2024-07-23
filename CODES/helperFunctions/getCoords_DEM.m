function [xyz, localX, localY, Z, Eastings, Northings] = getCoords_DEM(Products, DEM)
% getCoords returns the (x,y,z) world coordinates for the dimensions specified in Products.
%% Syntax
%            [xyz] = getCoords(Products)
%
%% Description
%   Args:
%           Products (structure) : Single Products object. All necessary variables given in define_grid, define_xtransect, or define_ytransect
%                       type (string) : 'Grid', 'xTransect', 'yTransect'
%                       frameRate (double) : frame rate of product (Hz)
%                       lat (double) : latitude of origin grid
%                       lon (double): longitude of origin grid
%                       angle (double): shorenormal angle of origid grid (degrees CW from North)
%                       xlim (double): [1 x 2] cross-shore limits of grid (+ is offshore of origin) (m)
%                       ylim (double) : [1 x 2] along-shore limits of grid (+ is to the right of origin looking offshore) (m)
%                       dx (double) : Cross-shore resolution (m)
%                       dy (double) : Along-shore resolution (m)
%                       x (double): Cross-shore distance from origin (+ is offshore of origin) (m)
%                       y (double): Along-shore distance from origin (+ is to the right of the origin looking offshore) (m)
%                       z (double) : Elevation - can be empty or array of DEM values (NAVD88 m)
%                       tide (double) : Tide level (NAVD88 m)
%           DEM (structure) : Digital Elevation Map Data
%                       time (datetime) : date of jumbo survey used
%                       type (cell array) : Survey type for each transect
%                       MOP (cell array) : Mop number of each x transect
%                       X (array): [mop_length x cross-shore length] - Eastings
%                       Y (array): [mop_length x cross-shore length] - Northings
%                       Z (array): [mop_length x cross-shore length] - Elevation (NAVD88m)
%                       min_tide (double) : minimum tide that day (NAVD88m) - limit of subaerial survey when a full profile was taken
%
%   Returns:
%       xyz (double) : [m x 3] (x, y, z) world coordinates for Products. Rotated according to Product.angle.
%       localX (double) : [y x x] local X coordinates (+x is offshore, m)
%       localY (double) : [y x x] local Y coordinates (+y is right of origin, m)
%       Z (double) : [y x x] Z coordinate - tide level
%       Eastings (double) : [y x x] Eastings coordinates (m)
%       Northings (double) : [y x x] Northings coordinates (m)
%
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jan 2024;

%% Data
assert(isa(Products, 'struct'), 'Error (getCoords_DEM): Products must be a structure.')
assert(size(Products,2)==1, 'Error (getCoords_DEM): Products must be a single object structure. Pass as Products(pp).')
assert(isfield(Products, 'lat'), 'Error (getCoords_DEM): Products must have lat field.')
assert(isfield(Products, 'lon'), 'Error (getCoords_DEM): Products must have lon field.')
assert(isfield(Products, 'angle'), 'Error (getCoords_DEM): Products must have angle field.')
assert(isfield(Products, 'tide'), 'Error (getCoords_DEM): Products must have tide field.')
assert(isfield(Products, 'xlim'), 'Error (getCoords_DEM): Products must have xlim field.')
assert(isfield(Products, 'ylim'), 'Error (getCoords_DEM): Products must have ylim field.')
assert(isfield(Products, 'type'), 'Error (getCoords_DEM): Products must have type field.')
assert(isfield(Products, 'x'), 'Error (getCoords_DEM): Products must have x field.')
assert(isfield(Products, 'y'), 'Error (getCoords_DEM): Products must have y field.')

%%
% Get origin coordinates
[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);

% Reorganize coordinates
if ~isempty(Products.xlim)
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
end % if ~isempty(Products.xlim)
if ~isempty(Products.ylim)
    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
end % if ~isempty(Products.ylim)

if contains(Products.type, 'Grid')
    ixlim = x2 - Products.xlim;
    iylim = y2 + Products.ylim;
    [X, Y]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));
elseif contains(Products.type, 'xTransect')
    ixlim = x2 - Products.xlim;
    iy = y2 + Products.y;
    X = (ixlim(1):Products.dx:ixlim(2))';
    Y = X.*0+iy;
    X=X'; Y=Y';
elseif contains(Products.type, 'yTransect')
    if Products.x < 0; Products.x = -Products.x; end
    ix = x2 - Products.x;
    iylim = y2 + Products.ylim;
    Y = (iylim(1):Products.dy:iylim(2))';
    X = Y.*0 + ix;
    X=X'; Y=Y';
end % if contains(Products.type, 'Grid')




%% Rotation
localX=X - x2;
localY=Y - y2;

Xout=localX.*cosd(Products.angle-270)+localY.*sind(Products.angle-270);
Yout=localY.*cosd(Products.angle-270)-localX.*sind(Products.angle-270);


localX = -localX;

Eastings = Xout + x2;
Northings = Yout + y2;


%% DEM
F = scatteredInterpolant(DEM.X(:), DEM.Y(:), DEM.Z(:));
Z = F(Eastings, Northings);
if all(isempty(Z)) | all(isnan(Z))
    iz=Products.tide;
    Z = X.*0 + iz;
else
    for ii = 1:size(X,1)
        P = InterX([Eastings(ii,:);Z(ii,:)],[Eastings(ii,:);Products.tide*ones(1,length(Eastings(ii,:)))]);
        if isempty(P)
            id = size(X,2);
        else
            [~,id] = min(abs(Eastings(ii,:) - P(1)));
        end
        Z(ii,1:id) = Products.tide;
    end
end % if isempty(Products.z) || isnan(Products.z)

%% Concatinate array
xyz = [Xout(:) Yout(:) Z(:)];
xyz = xyz+[x2 y2 0];
end

