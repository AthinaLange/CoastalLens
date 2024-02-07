function [mask] = select_ocean_mask(I)
%   select_ocean_mask returns a binary mask between two selected edge points - suitable for
%   removing the ocean from oblique coastal imagery
%% Syntax
%           [mask] = select_ocean_mask(I)
%
%% Description
%   Args:
%           I (uint8 image) : Image to show where mask should be applied
%
%   Returns:
%           mask (logical matrix) : binary mask covering area above user
%                                               selected points (same dimensions as I)
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Data
assert(isa(I, 'uint8'), 'Error (select_ocean_mask): I must be an image.')
%%
[m,n,~]=size(I);
figure(1);clf
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
rectangle('Position', [n-n/20 1 n/20 m], 'EdgeColor', 'red', 'LineWidth', 3);
a = drawpoint();
zoom out
pointhandles(2,:) = a.Position;

mask = imcomplement(poly2mask([0 n n 0], [pointhandles(1,2) pointhandles(2,2) 0 0], m, n));
end
