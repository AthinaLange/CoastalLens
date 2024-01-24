function [image_gcp] = select_image_gcp(I, image_fig)
%   Choose GCP Coordinates on Image
%
%% Syntax
%           [image_gcp] = select_image_gcp(I)
%% Description
%   Args:
%           I (uint8) : Image to select gcp points in
%
%   Returns:
%          image_gcp (array) : [2 x n] gcp coordinates for n points in image
%
% Click on however many GCP you would like to use
% To exit, click outside image
%
%
%% Example 1
%
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; Last revision: XXX

%%
% Load in initial frame
ax = axes('Parent', image_fig);
image(I, 'Parent', ax)
hold on
pan on

title('Click outside image when done selecting points.', 'Parent',ax)

pointhandles = [NaN,NaN];
while true
    % Wait for user to click a point
    a = drawpoint(ax);
    zoom out
    if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1))
        break;  % Exit the loop when Enter is pressed
    else
        pointhandles(end+1,:) = a.Position;
    end
end
pointhandles(1,:)=[];
clear h
cla(ax)
imshow(I, 'Parent', ax)
hold on
for ii = 1:size(pointhandles,1)
    h(ii) = drawpoint('Position', pointhandles(ii,:), 'Label', ['GCP ' char(string(ii))]);
end
title('Please check that you are happy with your ground control points. Otherwise please drag points to correct locations. Click enter when finished.')
%% Allow for last minute changes to happen

        for ii = 1:length(h)
            image_gcp(ii,:) = h(ii).Position;
        end


figure;
imshow(I)
hold on
scatter(image_gcp(:,1), image_gcp(:,2), 50, 'r')
for ii = 1:length(image_gcp)
    text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
end
end
