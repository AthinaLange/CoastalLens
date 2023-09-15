%% select_survey_gcp

% there has to be a more efficient and accurate way to do this - pull
% points from LiDAR

answer = questdlg('Do you want to select from LiDAR/SfM or image first?', 'GCP locations', 'Image', 'LiDAR/SfM', 'Image');
switch answer
    case 'Image'
        %% Choose GCP Coordinates on Image
       select_image_gcp
        %% Find corresponding points on LiDAR
        select_pointcloud_gcp
        survey_gcp = selectedPoints;
    case 'LiDAR'
        %% Get LiDAR GCPs
        answer2 = questdlg('Do you have a LiDAR/SfM template for this location? ', 'LiDAR/SfM GCP template', 'Yes', 'No', 'No');
        switch answer2
            case 'Yes'
                disp('Load in LiDAR/SfM gcp template.')
                [temp_file, temp_file_path] = uigetfile(global_dir, 'LiDAR/SfM GCP template');
                load(fullfile(temp_file_path, temp_file)); clear temp_file*
                if ~exist('survey_gcp', 'var')
                    disp('LiDAR/SfM GCPs not correct.')
                    disp('Select LiDAR/SfM GCPs.')
                    gcp_num = str2double(inputdlg({'How many LiDAR/SfM GCPs do you want to find?'}));
                    select_pointcloud_gcp
                    survey_gcp = selectedPoints;
                end
            case 'No'
                disp('Select LiDAR/SfM GCPs.')
                gcp_num = str2double(inputdlg({'How many LiDAR/SfM GCPs do you want to find?'}));
                select_pointcloud_gcp
                survey_gcp = selectedPoints;
        end

        % plot LiDAR/SfM gcps
        hLid = figure(2);clf
        scatter3(Points(:,1), Points(:,2), Points(:,3), 20, cPoints, 'filled')
        colorbar
        caxis([0 20])
        zlim([0 20])
        xlim([min(survey_gcp(:,1))-50 max(survey_gcp(:,1))+50])
        ylim([min(survey_gcp(:,2))-50 max(survey_gcp(:,2))+50])
        hold on; % so we can highlight clicked points without clearing the figure
        scatter3(survey_gcp(:,1), survey_gcp(:,2), survey_gcp(:,3)+.2, 100, 'r', 'filled')
        for ii = 1:length(survey_gcp)
            text(survey_gcp(ii,1)+1, survey_gcp(ii,2)+1, survey_gcp(ii,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
        view(-90,90)

        %% Choose GCP Coordinates on Image
        select_image_gcp
end

        %% Allow for last minute changes to happen
        answer2 = questdlg('Are you happy with image GCP locations?', 'Image GCP locations', 'Yes', 'Yes');
        switch answer2
            case 'Yes'
                for ii = 1:length(h)
                    image_gcp(ii,:) = h(ii).Position;
                end
        end

        figure(3);clf
        subplot(122)
        imshow(I)
        hold on
        scatter(image_gcp(:,1), image_gcp(:,2), 50, 'r', 'filled')
        for ii = 1:length(image_gcp)
            text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
        subplot(121)
        scatter3(Points(:,1), Points(:,2), Points(:,3), 20, cPoints), 'filled')
        colorbar
        caxis([0 20])
        zlim([0 20])
        xlim([min(survey_gcp(:,1))-50 max(survey_gcp(:,1))+50])
        ylim([min(survey_gcp(:,2))-50 max(survey_gcp(:,2))+50])
        hold on; % so we can highlight clicked points without clearing the figure
        scatter3(survey_gcp(:,1), survey_gcp(:,2), survey_gcp(:,3)+.2, 100, 'r', 'filled')
        for ii = 1:length(survey_gcp)
            text(survey_gcp(ii,1)+1, survey_gcp(ii,2)+1, survey_gcp(ii,3)+.4, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
        view(-90,90)

%% 

% 
% %% select_lidar_gcp
% % runing into meshgrid problems here, that sometimes there are two
% % elevations that are very similar. 
% 
% fLid = figure(2);clf;
% scatter3(lidarPoints(:,1), lidarPoints(:,2), lidarPoints(:,3), 20, lidarPoints(:,3), 'filled')
% set(gca,'YDir', 'reverse')
% colorbar
% caxis([0 20])
% zlim([0 20])
% hold on; % so we can highlight clicked points without clearing the figure
% 
% for ii = 1:length(h)
%     sprintf('Find GCP %i.', ii)
%     pause
%     point = get(gca, 'CurrentPoint'); % mouse click position
%         camPos = get(gca, 'CameraPosition'); % camera position
%         camTgt = get(gca, 'CameraTarget'); % where the camera is pointing to
% 
%         camDir = camPos - camTgt; % camera direction
%         camUpVect = get(gca, 'CameraUpVector'); % camera 'up' vector
% 
%         % build an orthonormal frame based on the viewing direction and the 
%         % up vector (the "view frame")
%         zAxis = camDir/norm(camDir);    
%         upAxis = camUpVect/norm(camUpVect); 
%         xAxis = cross(upAxis, zAxis);
%         yAxis = cross(zAxis, xAxis);
% 
%         rot = [xAxis; yAxis; zAxis]; % view rotation 
% 
%         % the point cloud represented in the view frame
%         rotatedPointCloud = rot * lidarPoints'; 
% 
%         % the clicked point represented in the view frame
%         rotatedPointFront = rot * point' ;
% 
%         % find the nearest neighbour to the clicked point 
%         pointCloudIndex = dsearchn(rotatedPointCloud(1:2,:)', ... 
%             rotatedPointFront(1:2));
% 
%         selectedPoint = lidarPoints(pointCloudIndex,:)';
%         fprintf('you clicked on point number %d\n', pointCloudIndex);
%         selectedPoints(ii,:)=selectedPoint;
%         scatter3(selectedPoints(:,1), selectedPoints(:,2), selectedPoints(:,3)+.2, 100, 'r', 'filled')
% end
% 
% lidar_gcp = selectedPoints;
% 
% 
% %%
% x=lidarPoints(:,1);
% y=lidarPoints(:,2);
% z=lidarPoints(:,3);
% 
% hLid = figure(2);clf;
% scatter3(lidarPoints(:,1), lidarPoints(:,2), lidarPoints(:,3), 20, lidarPoints(:,3), 'filled')
% set(gca,'YDir', 'reverse')
% colorbar
% caxis([0 20])
% hold on
% %%
% unique_xy=unique(lidarPoints(:,1:2), 'rows');
% %%
% hLid = figure(2);clf;
% scatter3(lidarPoints(:,1), lidarPoints(:,2), lidarPoints(:,3), 20, lidarPoints(:,3), 'filled')
% set(gca,'YDir', 'reverse')
% colorbar
% caxis([0 20])
% hold on
% T = delaunay(lidarPoints(:,1), lidarPoints(:,2));
% trimesh(T,lidarPoints(:,1), lidarPoints(:,2), lidarPoints(:,3),"FaceAlpha",0)
% title('Click Esc when done selecting points.')
% %%
% userStopped = false; 
% pointhandles = [NaN,NaN];
% while ~userStopped
%     a = drawpoint(); 
%     if ~isvalid(a) || isempty(a.Position)
%         % End the loop
%         userStopped = true;
%     else
%         % store point object handle
%         pointhandles(end+1,:) = a.Position; 
%     end
% end
% pointhandles(1,:)=[];
% %%
% [pointhandles] = sortrows(pointhandles,2);
% %%
% hLid; clf
% scatter3(lidarPoints(:,1), lidarPoints(:,2), lidarPoints(:,3), 20, lidarPoints(:,3), 'filled')
% set(gca,'YDir', 'reverse')
% colorbar
% caxis([0 20])
% hold on
% for ii = 1:size(pointhandles,1)
%     k=dsearchn(lidarPoints(:,1:2), pointhandles(ii,:));
%     lidar_gcp(ii,:) = lidarPoints(k,:);
%     scatter3(lidar_gcp(ii,1), lidar_gcp(ii,2),lidar_gcp(ii,3), 100, 'r', 'filled')
%     text(lidar_gcp(ii,1), lidar_gcp(ii,2),lidar_gcp(ii,3), ['GCP ' char(string(ii))], 'FontSize', 14)
% end
% title('Please check that you are happy with your ground control points. Otherwise please drag points to correct locations. Click enter when finished.')
% %pause
% %%
% clf
% % Example data for demonstration
% x = rand(1, 100);
% y = rand(1, 100);
% z = rand(1, 100);
% 
% % Create the 3D scatter plot
% scatter3(x, y, z, 'filled');
% xlabel('X');
% ylabel('Y');
% zlabel('Z');
% 
% % Get user input for selecting points
% n_points = 0;  % Initialize the number of selected points
% selected_coordinates = [];  % Initialize an empty array to store the coordinates
% 
% while true
%     % Wait for user to click a point
%     [x_coord, y_coord] = ginput(1);
% 
%     % Check if the user pressed a key other than mouse click (e.g., Enter to finish)
%     key = get(gcf, 'CurrentCharacter');
%     if double(key) == 13  % Enter key
%         break;  % Exit the loop when Enter is pressed
%     end
% 
%     % Increment the number of selected points
%     n_points = n_points + 1;
% 
%     % Store the selected coordinates
%     selected_coordinates(n_points, :) = [x_coord, y_coord];
% 
%     % Plot a marker at the selected point
%     hold on;
%     plot3(x_coord, y_coord, 0, 'ro', 'MarkerSize', 10);
%     hold off;
% end
% 
% % Display the selected coordinates
% disp('Selected Coordinates:');
% disp(selected_coordinates);
% 
% 
% %%
% figure(1);clf
% handle.a = axes;
% % generate random x,y,z values
% handle.x = lidarPoints(:,1);
% handle.y = lidarPoints(:,2);
% handle.z = lidarPoints(:,3);
% % plot in 3D
% handle.p = scatter3(handle.x,handle.y,handle.z,20, handle.z, 'filled');
% xlabel('Cross-shore Distance (m)');
% ylabel('Alongshore Distance (m)');
% zlabel('Elevation (m)');
% handle.a.ZAxis.Limits=[2 20]
% caxis([2 20])
% % add callback when point on plot object 'handle.p' is selected
% % 'click' is the callback function being called when user clicks a point on plot
% handle.p.ButtonDownFcn = {@click,handle};
% % definition of click
% function pt_return = click(obj,eventData,handle)
%     % co-ordinates of the current selected point
%     Pt = handle.a.CurrentPoint(2,:);
%     % find point closest to selected point on the plot
%     for k = 1:5
%         arr = [handle.x(k) handle.y(k) handle.z(k);Pt];
%         distArr(k) = pdist(arr,'euclidean');
%     end
%     [~,idx] = min(distArr);
%     % display the selected point on plot
%     disp([handle.x(idx) handle.y(idx) handle.z(idx)]);
%     pt_return = [handle.x(idx) handle.y(idx) handle.z(idx)]
% end
% 
% %%
% %  % Display Image
% %     f1=figure;
% % 
% %     scatter(lidarPoints(:,1), lidarPoints(:,2), 20, lidarPoints(:,3), 'filled')
% %     set(gca,'YDir', 'reverse')
% %     colorbar
% %     caxis([0 20])
% % 
% %     xmin = min(lidarPoints(:,1));
% %     xmax = max(lidarPoints(:,1));
% %     ymin = min(lidarPoints(:,2));
% %     ymax = max(lidarPoints(:,2));
% %     xlim([xmin xmax])
% %     ylim([ymin ymax])
% %     xx=xlabel({ 'Cross-shore Distance';'Click Here in Cross-Hair Mode To End Collection '});
% %     ylabel('Alongshore Distance')
% %     hold on
% %    %%
% %    title('Zoom axes as Needed. Press Enter to Initiate Click')
% %         pause
% % 
% %         % Allow User to Click
% %         title('Left Click to Save. Right Click to Delete')
% %         [x,y,button] = ginput(1);
% % 
% %     %%
% %     % Clicking Mechanism
% %     x=1;
% %     y=1;
% %     z=1;
% %     button=1;
% %     UVclick=[];
% % 
% %     while x >= xx.Position(1) & y <= xx.Position(2) & z >= xx.Position(3) % Clicking figure bottom will end clicking opportunity
% % 
% %         % Allow User To Zoom
% %         title('Zoom axes as Needed. Press Enter to Initiate Click')
% %         pause
% % 
% %         % Allow User to Click
% %         title('Left Click to Save. Right Click to Delete')
% %         [x,y,button] = ginput(1);
% % 
% % 
% %         % If a left click, ask user for number, store, and display
% %         if button==1  & (x<=xx.Position(1) & y<=xx.Position(2))
% % 
% %             % Plot GCP in Image
% %             plot(x,y,'ro','markersize',10,'linewidth',3)
% % 
% %             title('Enter GCP Number in Command Window')
% % 
% %             % User Input for Number
% %             num=input('Enter GCP Number:');
% % 
% %             % Store Values
% %             UVclick=cat(1,UVclick, [num x y]);
% % 
% %             % Display GCP Number In Image
% %             text(x+30,y,num2str(num),'color','r','fontweight','bold','fontsize',15)
% % 
% %             % Display Values
% %             disp(['GCP ' num2str(num) ' [U V]= [' num2str(x) ' ' num2str(y) ']'])
% %             disp(' ')
% %             figure(f1)
% %             zoom out
% %         end
% % 
% %         % If a right click, program will delete nearest point, mark UVClick
% %         % Entry as unusable with value -99.
% %         if button==3 & (x<=c & y<=r)
% %             % Find Nearest Marker
% %             Idx = knnsearch(UVclick(:,2:3),[x y]);
% % 
% %             % Turn the visual display off.
% %             N=length(UVclick(:,1,1))*2+1; % Total Figure Children (Image+ 1 Text + 1 Marker for each Click)
% %             f1.Children(1).Children(N-(Idx*2)).Visible='off';   % Turn off Text
% %             f1.Children(1).Children(N-(Idx*2-1)).Visible='off'; % Turn off Marker
% % 
% %             %Display Deleted GCP
% %             disp(['Deleted GCP ' num2str(UVclick(Idx,1))]);
% % 
% %             % Set UVclick GCP number to Unusable Value
% %             UVclick(Idx,1)=-99;
% %             zoom out
% %         end
% % 
% %     end
% % 
% %     % Filter out values that were to be deleted
% %     IND=find(UVclick(:,1) ~= -99);
% %     UVsave=UVclick(IND,:);
% % 
% %     % Sort so GCP Numbers are in order
% %     [ia ic]=sort(UVsave(:,1));
% %     UVsave(:,:)=UVsave(ic,:);
% % 
% %     % Place in GCP Format
% %     for k=1:length(UVsave(:,1))
% %         gcp(k).UVd=UVsave(k,2:3);
% %         gcp(k).num=UVsave(k,1);
% %     end
% % 
% % 
% % 
% % 
% % 
% % 
% % 
% % 
% % 
% % 
% % 
% % 
% % 
% % %% select_image_gcp
% % 
% % 
% % 
% % 
% % 
% % 
% % 
