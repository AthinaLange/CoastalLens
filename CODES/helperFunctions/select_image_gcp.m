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
I = imread( fullfile(odir, 'Processed_data', 'undistortImage.png'));
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
