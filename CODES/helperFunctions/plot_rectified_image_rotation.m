function plot_rectified_image_rotation(Products)
%   plot_rectified_image_rotation plots the 1st rectified image in world and local coordinates.
%% Syntax
%            plot_rectified_image_rotation(Products(1))
%
%% Description
%   Args:
%           Products (structure) : Single Products object. 
%                       angle (double) : shorenormal angle of origid grid (degrees CW from North)
%                       localX (double) : [y x x] local X coordinates (+x is offshore, m)
%                       localY (double) : [y x x] local Y coordinates (+y is right of origin, m)
%                       Eastings (double) : [y x x] Eastings coordinates (m)
%                       Northings (double) : [y x x] Northings coordinates (m)
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
%
%   Returns:
%
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024;

%% Data
assert(isa(Products, 'struct'), 'Error (plot_rectified_image_rotation): Products must be a structure.')
assert(size(Products,2)==1, 'Error (plot_rectified_image_rotation): Products must be a single object structure. Pass as Products(pp).')
assert(isfield(Products,'Eastings'), 'Error (plot_rectified_image_rotation): Products have Eastings field.')
assert(isfield(Products,'Northings'), 'Error (plot_rectified_image_rotation): Products have Northings field.')
assert(isfield(Products,'localX'), 'Error (plot_rectified_image_rotation): Products have localX field.')
assert(isfield(Products,'localY'), 'Error (plot_rectified_image_rotation): Products have localY field.')
assert(isfield(Products,'Irgb_2d'), 'Error (plot_rectified_image_rotation): Products have Irgb_2d field.')
assert(isfield(Products,'angle'), 'Error (plot_rectified_image_rotation): Products have angle field.')

[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);
figure(1);clf
tiledlayout(1,2)
nexttile()
%yy = flipud(Products.Northings);
H=tcolor(Products.Eastings, Products.Northings, squeeze(Products.Irgb_2d(1,:,:,:)));
xlabel('Eastings (m)')
ylabel('Northings (m)')
set(gca, 'FontSize', 20)
xticks([round(min(min(Products.Eastings))): 100: round(max(max(Products.Eastings)))])
yticks([round(min(min(Products.Northings))): 100: round(max(max(Products.Northings)))])
hold on
plot(x2, y2, 'g.', 'MarkerSize', 50)


nexttile()
H=tcolor(Products.localX, Products.localY, squeeze(Products.Irgb_2d(1,:,:,:)));
xlabel('Cross-shore Distance (m)')
ylabel('Along-shore Distance (m)')
set(gca, 'FontSize', 20)
hold on
plot(0, 0, 'g.', 'MarkerSize', 50)
xticks([round(min(min(Products.localX))): 100: round(max(max(Products.localX)))])
yticks([round(min(min(Products.localY))): 100: round(max(max(Products.localY)))])

if Products.angle > 180
    set(gca, 'XDir', 'reverse')
end

end