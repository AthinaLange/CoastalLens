function plot_grid(Products, I, intrinsics_CIRN, extrinsics)
%
% Plot 1 grid as defined in Products
%
[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);
localExtrinsics = localTransformExtrinsics([x2 y2], Products.angle-270, 1, extrinsics);

if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
ixlim = x2 - Products.xlim;

if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
iylim = y2 + Products.ylim;

[iX, iY]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));

% DEM stuff
if isempty(Products.z)
    iz=0;
elseif length(Products.z) == 1 % only tide level
    iz = Products.z;
else % DEM
    iz = Products.z;
end
iZ=iX*0+iz;

X=iX; Y=iY; Z=iZ;
[localX, localY]=localTransformEquiGrid([x2 y2], Products.angle-270-7,1,iX,iY);
localZ=localX.*0+iz;

[Ir]= imageRectifier(I,intrinsics_CIRN,extrinsics,X,Y,Z,1);
subplot(2,2,[2 4])
title('World Coordinates')

[localIr]= imageRectifier(I,intrinsics_CIRN,localExtrinsics,localX,localY,localZ,1);

subplot(2,2,[2 4])
title('Local Coordinates')
