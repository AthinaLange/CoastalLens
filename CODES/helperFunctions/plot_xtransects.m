function plot_xtransects(Products, I, intrinsics, extrinsics)
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
for pp = ids_xtransect% repeat for all xtransects
    jj=jj+1;
    [xyz, ~,~,~] = getCoords(Products(pp));
    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    aa=xyz-[x2 y2 0]; 
    iP = round(world2img(xyz, pose2extr(extrinsics), intrinsics));

    scatter(iP(:,1), iP(:,2), 25, 'filled')
   xlim([0 size(I,2)])
    ylim([0 size(I,1)])

    le{jj}= [Products(pp).type ' - x = ' char(string(Products(pp).y)) 'm'];

end % for pp = 1:length(ids_xtransect)
legend(le)

