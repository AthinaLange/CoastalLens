function [xyz, X, Y, Z] = getCoords(Products)
%   getCoords returns the (x,y,z) world coordinates for the dimensions
%   specified in Products.
%% Syntax
%            [xyz] = getCoords(Products)
%
%% Description
%   Args:
%           Products (structure) : Single Products object. All necessary variables given in define_grid, define_xtransect, or define_ytransect
%
%   Returns:
%       xyz (double) : [m x 3] (x, y, z) world coordinates for Products. Rotated according to Product.angle.
%
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024;

%% Data
assert(isa(Products, 'structure'), 'Error (getCoords): Products must be a structure.')
assert(size(Products,2)==1, 'Error (getCoords): Products must be a single object structure. Pass as Products(pp).')

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
if isempty(Products.z) || isnan(Products.z)
    iz=0; 
else
    iz = Products.z; 
end % if isempty(Products.z) || isnan(Products.z)

if contains(Products.type, 'Grid')
    ixlim = x2 - Products.xlim;
    iylim = y2 + Products.ylim;
    [X, Y]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));
elseif contains(Products.type, 'xTransect')
    ixlim = x2 - Products.xlim;
    iy = y2 + Products.y;
    X = [ixlim(1):Products.dx:ixlim(2)]';
    Y = X.*0+iy;
elseif contains(Products.type, 'yTransect')
    if Products.x < 0; Products.x = -Products.x; end
    ix = x2 - Products.x;
    iylim = y2 + Products.ylim;
    Y = [iylim(1):Products.dy:iylim(2)]';
    X = Y.*0 + ix;
end % if contains(Products.type, 'Grid')

Z = X.*0 + iz;


%% Rotation
ep=X-x2;
np=Y-y2;

Xout=ep.*cosd(Products.angle-270)+np.*sind(Products.angle-270);
Yout=np.*cosd(Products.angle-270)-ep.*sind(Products.angle-270);

xyz = [Xout(:) Yout(:) Z(:)];
xyz = xyz+[x2 y2 0];
end

