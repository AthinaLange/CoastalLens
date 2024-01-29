function plot_grid(Products, I, intrinsics, extrinsics)
%
% Plot 1 grid as defined in Products
%
[xyz, ~,~,~] = getCoords(Products);
[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);
aa=xyz-[x2 y2 0];
iP = round(world2img(xyz, pose2extr(extrinsics), intrinsics));

figure(1);clf
image(I)
hold on
scatter(iP(:,1), iP(:,2), 25, 'filled')
xlim([0 size(I,2)])
ylim([0 size(I,1)])
 id=find(min(abs(aa(:,[1 2])))==abs(aa(:,[1 2])));
scatter(iP(id(1),1), iP(id(1),2),50, 'g', 'filled')
legend('Grid', 'Origin')
end