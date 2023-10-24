% detectHorizonOnImages('images', 'images_output')
 %L = dir(pwd); L([L.isdir] == 1) = []; if ~isempty(L); L = string(extractfield(L, 'name')');end
 L=string('Initial_frame.jpg')
for k =1 :100:length(L)
        originalImage = imread(L(k));
        % to account for black pixels when undistorting Image
        lim = 50;
        
        Igray = rgb2gray(originalImage(lim:end-lim,lim:end-lim,:));%(50:end-50, 50:end-50,:));

        
        for ii = size(Igray,2):-1:1
            if any(Igray(:,ii,:)== 0)
               Igray(:,ii,:)=[];
            end
        end

        
        % Convert the image to grayscale
       % grayImage = rgb2gray(originalImage);
        
        % Detect the horizon line
        [horizon_x1, horizon_x2, horizon_y1, horizon_y2,im] = detectHorizonLine(Igray);
        
        % Plot the original image and horizon line
     figure(k)
        imshow(originalImage, 'InitialMagnification', 'fit');
        hold on;
        plot([horizon_x1, horizon_x2]+50, [horizon_y1, horizon_y2]+50, 'r', 'LineWidth', 2);
        xline(50)
        xline(3790)
        title('Grayscaled Image with Horizon Line (Red)');
        axis off;
end
%%

function [horizon_x1, horizon_x2, horizon_y1, horizon_y2,im] = detectHorizonLine(image_grayscaled)
    % Detect the horizon's starting and ending points in the given image
    % The horizon line is detected by applying Otsu's threshold method to
    % separate the sky from the remainder of the image.
    
    % Apply Gaussian blur
    image_blurred = imgaussfilt(image_grayscaled, .5);
    % image_blurred = medfilt2(image_grayscaled, [1, 50]);
    
    % Thresholding using Otsu's method
    threshold = graythresh(image_blurred);
    image_thresholded = imbinarize(image_blurred, threshold);
    image_thresholded = 1 - image_thresholded;
    
    % Perform morphological closing operation
    se = strel('rectangle', [9, 9]);
    image_closed = imclose(image_thresholded, se);
    im=image_closed;
    
    % Find horizon line coordinates
    horizon_x1 = 1;
    horizon_x2 = size(image_grayscaled, 2);
    [~, horizon_y1] = max(image_closed(:, horizon_x1));
    [~, horizon_y2] = max(image_closed(:, horizon_x2));
    
    % Adjust coordinates (MATLAB uses 1-based indexing)
    horizon_y1 = horizon_y1 - 1;
    horizon_y2 = horizon_y2 - 1;
end
