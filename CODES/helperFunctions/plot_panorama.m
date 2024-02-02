function [panorama] = plot_panorama(images, intrinsics, tforms)
         I = undistortImage(readimage(images, 1), intrinsics);
            for i = 1:numel(tforms)
                imageSize(i,:) = size(I);
                [xlim(i,:), ylim(i,:)] = outputLimits(tforms(i), [1 imageSize(i,2)], [1 imageSize(i,1)]);
            end
            
            maxImageSize = max(imageSize);
            
            % Find the minimum and maximum output limits.
            xMin = min([1; xlim(:)]);
            xMax = max([maxImageSize(2); xlim(:)]);
            
            yMin = min([1; ylim(:)]);
            yMax = max([maxImageSize(1); ylim(:)]);
            
            % Width and height of panorama.
            width  = round(xMax - xMin);
            height = round(yMax - yMin);
            
            % Initialize the "empty" panorama.
            panorama = zeros([height width 3], 'like', I);
            blender = vision.AlphaBlender('Operation', 'Binary mask', ...
                'MaskSource', 'Input port');
            
            % Create a 2-D spatial reference object defining the size of the panorama.
            xLimits = [xMin xMax];
            yLimits = [yMin yMax];
            panoramaView = imref2d([height width], xLimits, yLimits);
                for i = 1:length(images.Files)
                
                    I = undistortImage(readimage(images, i), intrinsics);
                
                    % Transform I into the panorama.
                    warpedImage = imwarp(I, tforms(i), 'OutputView', panoramaView);
                
                    % Generate a binary mask.
                    mask = imwarp(true(size(I,1),size(I,2)), tforms(i), 'OutputView', panoramaView);
                
                    % Overlay the warpedImage onto the panorama.
                    panorama = step(blender, panorama, warpedImage, mask);
                end
                
          
                
end