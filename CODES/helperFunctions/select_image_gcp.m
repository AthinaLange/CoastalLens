function [image_gcp] = select_image_gcp(I)
%% select_image_gcp
% Choose GCP Coordinates on Image
%
% Click on however many GCP you would like to use 
% To exit, click outside image
%
% Requires: odir
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023
%%
% Load in initial frame
hFig = figure(1);clf
image(I)
hold on
pan on

title('Click outside image when done selecting points.')

pointhandles = [NaN,NaN];
while true
    % Wait for user to click a point
    a = drawpoint(); 
    zoom out
    if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1)) 
        break;  % Exit the loop when Enter is pressed
    else
        pointhandles(end+1,:) = a.Position; 
    end
end
pointhandles(1,:)=[];
clear h
hFig; clf
imshow(I)
hold on
for ii = 1:size(pointhandles,1)
    h(ii) = drawpoint('Position', pointhandles(ii,:), 'Label', ['GCP ' char(string(ii))]);
end
title('Please check that you are happy with your ground control points. Otherwise please drag points to correct locations. Click enter when finished.')
 %% Allow for last minute changes to happen
        answer2 = questdlg('Are you happy with image GCP locations?', 'Image GCP locations', 'Yes', 'Yes');
        switch answer2
            case 'Yes'
                for ii = 1:length(h)
                    image_gcp(ii,:) = h(ii).Position;
                end
        end
        
        figure(3);clf
        imshow(I)
        hold on
        scatter(image_gcp(:,1), image_gcp(:,2), 50, 'r')
        for ii = 1:length(image_gcp)
            text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
