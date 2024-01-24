
function [xyz, Xout, Yout, Z] = getCoords(Products, extrinsics)

[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);

%localExtrinsics = localTransformExtrinsics([x2 y2], Products.angle-270, 1, extrinsics);


if contains(Products.type, 'Grid')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;

    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    [iX, iY]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));

    % DEM stuff
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    iZ=iX*0+iz;

    X=iX; Y=iY; Z=iZ;
   ep=iX-x2;
    np=iY-y2;
    
    % Rotation
    Xout=ep.*cosd(Products.angle-270)+np.*sind(Products.angle-270);
    Yout=np.*cosd(Products.angle-270)-ep.*sind(Products.angle-270);
    Z=Xout.*0+iz;

    xyz = [Xout(:) Yout(:) Z(:)];


elseif contains(Products.type, 'xTransect')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;
    iy = y2 + Products.y;

    X = [ixlim(1):Products.dx:ixlim(2)]';
    Y = X.*0+iy;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = X.*0 + iz;
    %Xout=X-x2;
    %Yout=Y-y2;
    [ Xout, Yout]= localTransformPoints([x2 y2], Products.angle-270,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
elseif contains(Products.type, 'yTransect')
    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    ix = x2 + Products.x;

    Y = [iylim(1):Products.dy:iylim(2)]';
    X = Y.*0+ix;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = Y.*0 + iz;
    [ Xout, Yout]= localTransformPoints([x2 y2],Products.angle-270,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
end
xyz = xyz+[x2 y2 0];

end

