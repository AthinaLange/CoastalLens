function plot_xtransects(Products, I, intrinsics_CIRN, extrinsics)
%
% Plot all xtransects as define in Products
%

ids_xtransect = find(contains(extractfield(Products, 'type'), 'xTransect'));

figure(5);clf
hold on
imshow(I)
hold on
title('Timestack')
jj=0;
for pp = ids_xtransect % repeat for all xtransects
    jj=jj+1;

    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    localExtrinsics = localTransformExtrinsics([x2 y2], Products(pp).angle-270, 1, extrinsics(1,:));

    if Products(pp).xlim(1) < 0; Products(pp).xlim(1) = -Products(pp).xlim(1); end
    if Products(pp).xlim(2) > 0; Products(pp).xlim(2) = -Products(pp).xlim(2); end
    ixlim = x2 - Products(pp).xlim;
    iX = [ixlim(1):Products(pp).dx:ixlim(2)];

    iY = y2 + Products(pp).y;

    % DEM stuff
    if isempty(Products(pp).z)
        iz=0;
    elseif length(Products(pp).z) == 1 % only tide level
        iz = Products(pp).z;
    else % DEM
        iz = Products(pp).z;
    end
    iZ=iX*0+iz;

    X=iX; Y=iY; Z=iZ;
    [localX, localY]=localTransformPoints([x2 y2], Products(pp).angle-270-7,1,iX,iY);
    localZ=localX.*0+iz;
    xyz = cat(2,localX(:), localY(:), localZ(:));

    [UVd] = xyz2DistUV(intrinsics_CIRN, localExtrinsics,xyz);

    UVd = reshape(UVd,[],2);
    plot(UVd(:,1),UVd(:,2),'*')
    xlim([0 intrinsics_CIRN(1)])
    ylim([0  intrinsics_CIRN(2)])

    le{jj}= [Products(pp).type ' - x = ' char(string(Products(pp).y)) 'm'];

end % for pp = 1:length(ids_xtransect)
legend(le)

