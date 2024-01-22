
function [mask] = define_ocean_mask(I)

[m,n,~]=size(I);
hFig = figure(1);clf
image(I)
xticks([])
yticks([])
pan on
title('Click point in ocean where mask should start (within red box).')
rec1 = rectangle('Position', [1 1 n/20 m], 'EdgeColor', 'red', 'LineWidth', 3);

a = drawpoint();
zoom out
pointhandles(1,:) = a.Position;
delete(rec1)
rec1 = rectangle('Position', [n-n/20 1 n/20 m], 'EdgeColor', 'red', 'LineWidth', 3);
a = drawpoint();
zoom out
pointhandles(2,:) = a.Position;

mask = imcomplement(poly2mask([0 n n 0], [pointhandles(1,2) pointhandles(2,2) 0 0], m, n));
end
