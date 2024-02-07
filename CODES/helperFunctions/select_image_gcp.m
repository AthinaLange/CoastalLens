function [image_gcp] = select_image_gcp(I, image_fig)
%   select_image_gcp returns pixel coordinates of selected points in image.
%% Syntax
%           [image_gcp] = select_image_gcp(I, image_fig)
%% Description
%   Args:
%           I (uint8 image) : image to select gcp points in
%           image_fig (figure handle) : figure handle for image to load in
%
%   Returns:
%          image_gcp (array) : [2 x n] gcp coordinates for n points in image
%
% Click on however many GCP you would like to use
% To exit, click outside image
%
% Passing the figure handles is necessary.
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; 

%% Data
assert(isa(I, 'uint8'), 'Error (select_image_gcp): I must be a uint8 image.')
assert(strcmp(class(image_fig), 'matlab.ui.Figure'), 'Error (select_image_gcp): image_fig must be a figure handle.')

%% Plot image
ax = axes('Parent', image_fig);
image(I, 'Parent', ax)
hold on
pan on

title('Requires minimum 4 points. Click outside image when done selecting points.', 'Parent',ax)

pointhandles = [NaN,NaN];
while true
    zoom on
    % Wait for user to click a point
    a = drawpoint(ax);
    zoom out
    if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1))
        break;  % Exit the loop when Enter is pressed
    else
        pointhandles(end+1,:) = a.Position;
    end % if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1))
end % while true
pointhandles(1,:)=[];

clear h
cla(ax)
imshow(I, 'Parent', ax)
hold on
for ii = 1:size(pointhandles,1)
    h(ii) = drawpoint('Position', pointhandles(ii,:), 'Label', ['GCP ' char(string(ii))]);
end % for ii = 1:size(pointhandles,1)

for ii = 1:length(h)
    image_gcp(ii,:) = h(ii).Position;
end % for ii = 1:length(h)

figure;
imshow(I)
hold on
size(image_gcp)
scatter(image_gcp(:,1), image_gcp(:,2), 50, 'r')
for ii = 1:size(image_gcp,1)
    text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
end % for ii = 1:size(image_gcp,1)
end
