function plot_ytransects(Products, I, intrinsics, extrinsics)
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
for pp = ids_ytransect % repeat for all ytransects
    jj=jj+1;
    [xyz, ~,~,~] = getCoords(Products(pp));
    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
    aa=xyz-[x2 y2 0];
    iP = round(world2img(xyz, pose2extr(extrinsics), intrinsics));

    scatter(iP(:,1), iP(:,2), 25, 'filled')
   xlim([0 size(I,2)])
    ylim([0 size(I,1)])

    le{jj}= [Products(pp).type ' - y = ' char(string(Products(pp).x)) 'm'];

end % for pp = 1:length(ids_ytransect)
legend(le)

