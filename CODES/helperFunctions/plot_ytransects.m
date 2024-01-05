function plot_ytransects(Products, I, intrinsics_CIRN, extrinsics)
%
% Plot all ytransects as define in Products
%

ids_ytransect = find(contains(extractfield(Products, 'type'), 'yTransect'));

figure(6);clf
hold on
imshow(I)
hold on
title('yTransect')
jj=0;
le={};
for pp = ids_ytransect % repeat for all xtransects
    jj=jj+1;

    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    localExtrinsics = localTransformExtrinsics([x2 y2], Products(pp).angle-270, 1, extrinsics);

    if Products(pp).ylim(1) > 0; Products(pp).ylim(1) = -Products(pp).ylim(1); end
    if Products(pp).ylim(2) < 0; Products(pp).ylim(2) = -Products(pp).ylim(2); end
    iylim = y2 + Products(pp).ylim;

    ix = x2 + Products(pp).x;

    Y = [iylim(1):Products(pp).dy:iylim(2)]';
    X = Y.*0+ix;
    if isempty(Products(pp).z); iz=0; else; iz = Products(pp).z; end
    Z = Y.*0 + iz;
    [ Xout, Yout]= localTransformPoints([x2 y2], Products(pp).angle-270,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));

    [UVd] = xyz2DistUV(intrinsics_CIRN, localExtrinsics,xyz);

    UVd = reshape(UVd,[],2);
    plot(UVd(:,1),UVd(:,2),'*')
    xlim([0 intrinsics_CIRN(1)])
    ylim([0  intrinsics_CIRN(2)])

    le{jj}= [Products(pp).type ' - y = ' char(string(Products(pp).y)) 'm'];

end % for pp = 1:length(ids_xtransect)
legend(le)

