
function [xyz, ep, np, Z] = getCoords(Products)

[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);

%localExtrinsics = localTransformExtrinsics([x2 y2], Products.angle-270, 1, extrinsics);


if contains(Products.type, 'Grid')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;

    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    [X, Y]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));

    % DEM stuff
    if isempty(Products.z); iz=0; elseif isnan(Products.z); iz=0; else; iz = Products.z; end
    Z=X*0+iz;

elseif contains(Products.type, 'xTransect')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;
    iy = y2 + Products.y;

    X = [ixlim(1):Products.dx:ixlim(2)]';
    Y = X.*0+iy;
    if isempty(Products.z); iz=0; elseif isnan(Products.z); iz=0; else; iz = Products.z; end
    Z = X.*0 + iz;    
  
elseif contains(Products.type, 'yTransect')
    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    if Products.x < 0; Products.x = -Products.x; end
    ix = x2 - Products.x;

    Y = [iylim(1):Products.dy:iylim(2)]';
    X = Y.*0+ix;
    if isempty(Products.z); iz=0; elseif isnan(Products.z); iz=0; else; iz = Products.z; end
    Z = Y.*0 + iz;

end



ep=X-x2;
np=Y-y2;

% Rotation
Xout=ep.*cosd(Products.angle-270)+np.*sind(Products.angle-270);
Yout=np.*cosd(Products.angle-270)-ep.*sind(Products.angle-270);

xyz = [Xout(:) Yout(:) Z(:)];
xyz = xyz+[x2 y2 0];
end

