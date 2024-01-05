%% run_extrinsics
%
% Tracks the image stabilization through flight
%
% If using Feature Detection (Monocular Visual Odometry)
%   - within region of interest (bottom cutoff %) detect SURF features
%   - extract features in first frame
%   - for all subsequent images:
% 	    - detect SURF features
% 	    - find matching features between current frame and first frame
%   - if using 2D rotation
% 	    - estimate 2D image transformation between matching features
%   - if using 3D rotation
% 	    - estimate essential matrix
% 	    - estimate relative pose based on essential matrix and matching features
% 	    - if multiple relative poses found
% 		    - get coordinates of origin (needs to be in the frame)
% 		    - project coordinates into image according to 3D transformations
% 		    - if projected point is outside image dimensions - pose is incorrect
% 		    - if multiple poses satisfy this - take smallest Euclidian distance between projected points in current frame and previous frame
% 	    - get worldPose for each frame from worldPose.A * relPose.A
%
%
% If using SCPs (similar to QCIT F_variableExtrinsicsSolution)
%   - Within radius of previous location of SCPs, find mean location of pixels above/below specified threshold. This becomes the new location of the SCP. Find new extrinsics based on new SCP locations.
%       - If no points above/below threshold, then user prompt to click the location of the point.
%       - If same point is clicked 5 times in the last 10 frames, then reasses radius and thresholds.
%       - If person walks across points, user can pause code and click on points until object gone. (STILL TBD)
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Nov 2023

%%  Input Data check
if exist('data_files','var') && isstruct(data_files) && isfield(data_files, 'folder') && isfield(data_files, 'name')
    %
else  % Load in all days that need to be processed.
    data_dir = uigetdir('.', 'DATA Folder');
    disp('Please select the days to process:')
    data_files = dir(data_dir); data_files([data_files.isdir]==0)=[]; data_files(contains({data_files.name}, '.'))=[];
    [ind_datafiles,~] = listdlg('ListString',{data_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'});
    data_files = data_files(ind_datafiles);
end
if exist('global_dir', 'var') && isstring(global_dir)
    %
else % select global directory
    disp('Please select the global directory.')
    global_dir = uigetdir('.', 'UAV Rectification');
    cd(global_dir)
end

%% Previous scripts data check
for dd = 1 : length(data_files)
    for ff = 1 : length(flights)

        % Input_data: Products, extract_Hz, and flights
        if ~exist(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'), 'file')
            disp('Please create an input_data.mat file with Products, extract_Hz, and flights.')
            % flights
            flights = dir(fullfile(data_files(dd).folder, data_files(dd).name)); flights([flights.isdir]==0)=[]; flights(contains({flights.name}, '.'))=[]; flights(contains({flights.name}, 'GCP'))=[];
            
            % Products
            answer = questdlg('Do you have a .mat Products file?', 'Product file', 'Yes', 'No', 'Yes');
            switch answer
                case 'Yes'
                    disp('Please select file of products you want to load in.')
                    disp('For CPG: CPG_data/products_Torrey.mat') %% XXX
                    [temp_file, temp_file_path] = uigetfile(global_dir, 'Product file');
                    load(fullfile(temp_file_path, temp_file)); clear temp_file*
    
                    if ~exist('Products', 'var')
                        disp('Please create Products file.')
                        disp('For CPG: construct DEM for appropriate day')
                        construct_MOPS_DEM %% XXX
                        user_input_products
                    end
                case 'No'
                    user_input_products
            end
            clear answer

            % extract_Hz
            info_Hz = unique([Products.frameRate]);
            extract_Hz = max(info_Hz);
            for hh = 1:length(info_Hz)
                if rem(max(info_Hz), info_Hz(hh)) == 0
                    sprintf('%i Hz data can be pulled from %i Hz data', info_Hz(hh), max(info_Hz))
                else
                    sprintf('%i Hz data CANNOT be pulled from %i Hz data', info_Hz(hh), max(info_Hz))
                    extract_Hz = [extract_Hz info_Hz(hh)];
                end
            end
            clear hh info_Hz
            save(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'), 'extract_Hz', 'Products', 'flights', '-append')
        end

        % Initial_coordinates: C, mov_id
        if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Initial_coordinates.mat'), 'file')
            disp('Please get a table of the metadata in C, and the id''s of the movie files (mov_id).')
            temp_name = string(inputdlg({'What is the file prefix?'}));
            drone_file_name = temp_name(1);
            [C, jpg_id, mov_id] = get_metadata(fullfile(flights(ff).folder, flights(ff).name), [data_files(dd).name '_' flights(ff).name], drone_file_name);
            save(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Inital_coordinates'),  'jpg_id', 'mov_id', 'C', '-append')
            sprintf('Store this variable in %s', 'Initial_coordinates.mat')
        end

        % IOEOVariable: ind_scp_method
        if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [data_files(dd).name '_' flights(ff).name '_IOEOVariable.mat']), 'file')
            disp('Please define a SCP method in ind_scp_method variable.')
            [ind_scp_method,tf] = listdlg('ListString',[{'Feature Matching'}, {'Using SCPs.'}],...
            'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Extrinsics Method'});
            save(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [data_files(dd).name '_' flights(ff).name '_IOEOVariable.mat']),'ind_scp_method')
            sprintf('Store this variable in %s', [data_files(dd).name '_' flights(ff).name '_IOEOVariable.mat'])
        end

        % IOEOInitial: worldPose, R, intrinsics, extrinsics, intrinsics_CIRN
        if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [data_files(dd).name '_' flights(ff).name '_IOEOInitial.mat']), 'file')
            disp('Depending on the SCP method, please include extrinsics and intrinsics information.')
            disp('If using Feature Matching: worldPose, R and intrinsics.')
            disp('If using SCPs: extrinsics and intrinsics_CIRN')
            % TODO
            sprintf('Store this variable in %s', [data_files(dd).name '_' flights(ff).name '_IOEOInitial.mat'])
        end


        % scpUVdInitial: scp (requires ind_scp_method and extract_Hz
        load(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [data_files(dd).name '_' flights(ff).name '_IOEOVariable.mat']), 'ind_scp_method')
        if ind_scp_method == 2 % SCP
            extract_Hz_dir=dir(fullfile(flights(ff).folder, flights(ff).name));
            extract_Hz_dir([extract_Hz_dir.isdir]==0)=[]; extract_Hz_dir(~contains({aa.name}, 'images_'))=[];
            for hh = 1:length(extract_Hz_dir)
                if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [data_files(dd).name '_' flights(ff).name '_scpUVdInitial_' char(string(extract(extract_Hz_dir(hh).name,digitsPattern))) 'Hz.mat']), 'file')
                    sprintf('For extract_Hz = %.1f Hz', char(string(extract(extract_Hz_dir(hh).name,digitsPattern))))
                    disp('Please define SCPs.')
                    % TODO
                    sprintf('Store this variable in %s', [data_files(dd).name '_' flights(ff).name '_scpUVdInitial_' char(string(extract(extract_Hz_dir(hh).name,digitsPattern))) 'Hz.mat'])
                end
            end % hh
        end % if ind_scp_method
    end % ff
end % dd


%% run_extrinsics
for dd = 1:length(data_files)
    clearvars -except dd *_dir user_email data_files
    cd(fullfile(data_files(dd).folder, data_files(dd).name))

    load(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'), 'Products', 'extract_Hz', 'flights')

    % repeat for each flight
    for ff = 1 : length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [data_files(dd).name '_' flights(ff).name];
        cd(odir)

        load(fullfile(odir, 'Processed_data', [oname '_IOEOVariable']),'ind_scp_method')
        if ind_scp_method == 1 % Using Feature Detection/Matching
            %% ========================FeatureDetection============================================
            %           - SMALL CHANGE: in reference to initial image to reduce accumulating drift errors
            %           - LARGE CHANGE: in reference to previous image - correct for accumulated drift later
            %  ===================================================================================
            load(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'worldPose', 'intrinsics')

            for hh = 1 : length(extract_Hz)
                imageDirectory = sprintf('images_%iHz', extract_Hz(hh));
                mkdir(sprintf('warped_images_%iHz', extract_Hz(hh)));
                %% First Frame
                images = imageDatastore(imageDirectory);

                viewId = 1;
                prevI = undistortImage(im2gray(readimage(images, 1)), intrinsics);

                % Detect features.
                prevPoints = detectSURFFeatures(prevI(R.cutoff:end,:), MetricThreshold=500); prevPoints.Location(:,2)=prevPoints.Location(:,2)+R.cutoff;
                numPoints = 500;
                prevPoints = selectUniform(prevPoints, numPoints, size(prevI));

                % Extract features.
                prevFeatures = extractFeatures(prevI, prevPoints);

                ogI = prevI;
                ogPoints = prevPoints;
                ogFeatures = prevFeatures;

                %% Subsequent Frames
                if contains(R.rot_answer, '2D') | worldPose.Translation == [0 0 0] % do 2D rotation
                    for viewId = 2:length(images.Files)
                        % Read and display the next image
                        Irgb = readimage(images, (viewId));

                        % Convert to gray scale and undistort.
                        I = undistortImage(im2gray(Irgb), intrinsics);

                        % WRT OG IMAGE
                        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, R.cutoff, numPoints, 'On');

                        % Eliminate outliers from feature matches.
                        [rotation, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));

                        if abs(rotation.RotationAngle) > 5
                            images.Files(viewId:end)=[];
                            break
                        end
                        R.FullRate_OGFrame(viewId) = rotation;
                        if rem(viewId, 30*extract_Hz(hh)) == 0
                            disp(viewId)
                            figure(200); clf; I2=imshowpair(undistortImage(readimage(images, 1), intrinsics), ...
                                imwarp(undistortImage(readimage(images, viewId), intrinsics), R.FullRate_OGFrame(viewId), OutputView=imref2d(size(readimage(images, viewId-1)))));
                            title(sprintf('Time = %.1f min', viewId/extract_Hz(hh)/60))
                            saveas(gca, sprintf('warped_images_%iHz/warped_%isec.jpg', extract_Hz(hh), viewId/extract_Hz(hh)))
                        end
                    end %for viewId = 2:length(images.Files)

                elseif contains(R.rot_answer, '3D') & worldPose.Translation ~= [0 0 0] % do 3D transformation
                    R.FullRate_Adjusted = worldPose;
                    for viewId = 2:length(images.Files)

                        % Read and display the next image
                        Irgb = readimage(images, (viewId));

                        % Convert to gray scale and undistort.
                        I = undistortImage(im2gray(Irgb), intrinsics);

                        % Detect Features
                        [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(ogFeatures, I, R.cutoff, numPoints, 'On');

                        try
                            [relPose, inlierIdx] = helperEstimateRelativePose(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)), intrinsics);
                        catch
                            % Get Essential Matrix
                            [E, inlierIdx] = estimateEssentialMatrix(ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)), intrinsics);

                            % Get the epipolar inliers.
                            indexPairs = indexPairs(inlierIdx,:);

                            % Compute the camera pose from the fundamental matrix.
                            [relPose, validPointFraction] = estrelpose(E, intrinsics, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:, 2)));
                        end

                        % if multiple relative Poses are obtained
                        if length(relPose) ~= 1
                            % Do first check if image projection is very wrong - origin of grid should be within image frame
                            [UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(Products(1).lat, Products(1).lon);
                            coords = horzcat(UTMEasting, UTMNorthing, 5.4);
                            for rr = length(relPose):-1:1
                                aa = worldPose.A *  relPose(rr).A;
                                absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                                iP = world2img(coords, pose2extr(absPose), intrinsics);
                                % if origin of grid is projected outside of image -> problem
                                if any(any(iP(:)> max(intrinsics.ImageSize))) || any(any(iP(:)< 0))
                                    relPose(rr) = [];
                                end % if any(any(iP(:)> max(intrinsics.ImageSize))) || any(any(iP(:)< 0))
                            end % for rr = length(relPose):-1:1

                            if length(relPose) ~= 1
                                % find projection point that is closest Euclidian distance to previous frame origin point
                                previP = world2img(coords, pose2extr(R.FullRate_Adjusted(viewId-1)), intrinsics);
                                clear dist
                                for rr = 1:length(relPose)
                                    aa = worldPose.A *  relPose(rr).A;
                                    absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                                    iP = world2img(coords, pose2extr(absPose), intrinsics);
                                    dist(rr) = pdist2(previP, iP);
                                end % for rr = 1:length(relPose)
                                [~,i]=min(dist);
                                relPose = relPose(i);
                            end % if length(relPose) ~= 1
                        end  % if length(relPose) ~= 1

                        R.FullRate_OGFrame(viewId) = relPose;
                        aa = worldPose.A *  relPose.A;
                        absPose = rigidtform3d(aa(1:3,1:3), aa(1:3,4));
                        R.FullRate_Adjusted(viewId) = absPose;

                        if rem(viewId, 30*extract_Hz(hh)) == 0
                            disp(viewId)
                            figure(200);clf
                            showMatchedFeatures(ogI,I, ogPoints(indexPairs(:,1)), currPoints(indexPairs(:,2)))
                            title(sprintf('Time = %.1f min', viewId/extract_Hz(hh)/60))
                            saveas(gca, sprintf('warped_images_%iHz/matching_%isec.jpg', extract_Hz(hh), viewId/extract_Hz(hh)))
                        end
                    end % for viewId = 2:length(images.Files)
                end % if contains(R.rot_answer, '2D')

                load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'C', 'mov_id')
                dts = 1/extract_Hz(hh);
                to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', tz);
                to.TimeZone = 'UTC';
                to = datenum(to);
                t=(dts./24./3600).*([1:length(images.Files)]-1)+ to;


                %  Save File
                save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_' char(string(extract_Hz(hh))) 'Hz' ]),'R', 'intrinsics', 't')

            end % for hh = 1 : length(extract_Hz)

        elseif ind_scp_method == 2 % CIRN QCIT F
            %% ========================CIRN_QCIT_F============================================
            if exist('user_email', 'var')
                sendmail(user_email{2}, [oname '- Please start extrinsics through time with SCPs.'])
            end
            answer = questdlg('Ready to start SCPs?', ...
                'SCPs begin',...
                'Yes', 'Yes');

            for hh = 1 : length(extract_Hz)

                imageDirectory = fullfile(odir, ['images_' char(string(extract_Hz(hh))) 'Hz']);

                % load SCP & extrinsics
                load(fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz(hh))) 'Hz']), 'scp')
                load(fullfile(odir, 'Processed_data',  [oname '_IOEOInitial']), 'extrinsics', 'intrinsics_CIRN')

                images = imageDatastore(imageDirectory);

                load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'C', 'mov_id')
                dts = 1/extract_Hz(hh);
                to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', tz);
                to.TimeZone = 'UTC';
                to = datenum(to);
                t=(dts./24./3600).*([1:length(images.Files)]-1)+ to;

                In=readimage(images, 1);
                f1=figure('Name', 'Image Viewer', 'Position', [100, 100, 1200, 800]);
                handles.pauseButton = uicontrol('Style', 'pushbutton', 'String', 'Pause', 'Position', [20, 20, 60, 30]);
                handles.imageAxis = axes('Parent', f1, 'Position', [0.1, 0.1, 0.8, 0.8]);

                imshow(In, 'Parent', handles.imageAxis)
                hold on
                for k=1:length(scp)
                    plot(scp(k).UVdo(1),scp(k).UVdo(2),'ro','linewidth',2,'markersize',10)
                end

                % Initiate Extrinsics Matrix and First Frame Imagery
                extrinsicsVariable=nan(length(images.Files),6);
                extrinsicsVariable(1,:)=extrinsics; % First Value is first frame extrinsics.
                % extrinsicsUncert(1,:)=initialCamSolutionMeta.extrinsicsUncert;

                [xyzo] = distUV2XYZ(intrinsics_CIRN, extrinsics, reshape([scp.UVdo],2,[]), 'z', [scp.z]);

                % Initiate and rename initial image, Extrinsics, and SCPUVds for loop
                extrinsicsVariable(1,:) = extrinsics;
                scpUVdn_full(1,:,:) = reshape([scp.UVdo],2,[]);
                imCount=1;
                click_counter = 0;
                clicks = zeros(length(scp), length(images.Files));
                %% ========================SCPthroughTime============================================
                %                           - Determine search area around bright or dark target.
                %  =====================================================================

                for k=2:length(images.Files)


                    % Assign last Known Extrinsics and SCP UVd coords
                    extrinsics_old=squeeze(extrinsicsVariable(k-1,:));
                    scpUVd_old=squeeze(scpUVdn_full(k-1,:,:));
                    clear extrinsics_new scpUVd_new

                    %  Load the New Image
                    In=readimage(images, k);
                    [m,n,~]=size(In);


                    % Find the new UVd coordinate for each SCPs
                    for j=1:length(scp)
                        [Udn, Vdn, i, udi,vdi] = thresholdCenter(In, scpUVd_old(1,j), scpUVd_old(2,j), scp(j).R, scp(j).T, scp(j).brightFlag);
                        if any(isnan([Udn Vdn])) % check if isempty or isnan
                            click_counter = click_counter + 1;
                            if click_counter == 1
                                if exist('user_email', 'var')
                                    sendmail(user_email{2}, [oname '- Problem with SCPs. Please click on correct point.'])
                                end
                            end

                            % Check if you've clicked last 5 pts:
                            clicks(j, k) = 1;
                            if k > 10 && sum(clicks(j, k-9:k))>=5
                                disp('Change SCP')
                                scp(j) = redo_SCP(scp(j), In, scpUVd_old(:,j));
                            end

                            sprintf('Reclick pt: %i', j)
                            fig = figure(100);clf
                            imshow(In)
                            hold on
                            plot(scpUVd_old(1,j),scpUVd_old(2,j),'ro','linewidth',2,'markersize',10)
                            legend('Previous point')
                            xlim([scpUVd_old(1,j)-n/10 scpUVd_old(1,j)+n/10])
                            ylim([scpUVd_old(2,j)-m/10 scpUVd_old(2,j)+m/10])

                            a = drawpoint();
                            zoom out
                            Udn= a.Position(1);
                            Vdn= a.Position(2);
                        end

                        %Assinging New Coordinate Location
                        scpUVd_new(:,j)=[Udn; Vdn];
                    end % for j=1:length(scp)

                    % Solve For new Extrinsics using last frame extrinsics as initial guess and scps as gcps
                    extrinsicsInitialGuess = extrinsics_old;
                    extrinsicsKnownsFlag = [0 0 0 0 0 0];
                    [extrinsics_new, extrinsicsError] = extrinsicsSolver(extrinsicsInitialGuess,extrinsicsKnownsFlag,intrinsics_CIRN,scpUVd_old',xyzo);

                    % Save Extrinsics in Matrix
                    scpUVdn_full(k,:,:)=scpUVd_new;
                    extrinsicsVariable(k,:)=extrinsics_new;
                    %extrinsicsUncert(imCount,:)=extrinsicsError;

                    % Plot new Image and new UV coordinates, found by threshold and reprojected
                    figure(f1);cla
                    % figure
                    imshow(In)
                    hold on

                    % Plot Newly Found UVdn by Threshold
                    plot(scpUVd_new(1,:),scpUVd_new(2,:),'ro','linewidth',2,'markersize',10)

                    % Plot Reprojected UVd using new Extrinsics and original xyzo coordinates
                    [UVd] = xyz2DistUV(intrinsics_CIRN,extrinsics_new,xyzo);
                    uvchk = reshape(UVd,[],2);
                    plot(uvchk(:,1),uvchk(:,2),'yo','linewidth',2,'markersize',10)

                    tt = char(images.Files(k));
                    title(['Frame: ' tt(7:11)])

                    legend('SCP Threshold','SCP Reprojected')
                    pause(.15)
                    set(handles.pauseButton, 'Callback', @(src, event) pauseLoop(src, event));
                    % Check if the pause button is pressed
                    while ishandle(handles.pauseButton) && strcmp(get(handles.pauseButton, 'UserData'), 'pause')
                        pause(0.1);
                    end
                    %saveas(gcf, sprintf('people_on_dot/Frame_%i.jpg', k))
                    %
                end % for k = 2:length(L)


                %  Saving Extrinsics and corresponding image names
                extrinsics=extrinsicsVariable;
                imageNames=images;

                % Saving MetaData
                variableCamSolutionMeta.scpPath=fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz(hh))) 'Hz']);
                variableCamSolutionMeta.scpo=scp;
                variableCamSolutionMeta.ioeopath=fullfile(odir, 'Processed_data',  [oname '_IOEOInitial']);
                variableCamSolutionMeta.imageDirectory=imageDirectory;

                % Calculate Some Statsitics
                variableCamSolutionMeta.solutionSTD= sqrt(var(extrinsics));

                %  Save File
                save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_' char(string(extract_Hz(hh))) 'Hz' ]),'extrinsics','t','variableCamSolutionMeta','imageNames','intrinsics_CIRN')

                %  Display
                disp(' ')
                disp(['Extrinsics for ' num2str(length(images.Files)) ' frames calculated.'])
                disp(' ')
                disp(['X Standard Dev: ' num2str(variableCamSolutionMeta.solutionSTD(1))])
                disp(['Y Standard Dev: ' num2str(variableCamSolutionMeta.solutionSTD(2))])
                disp(['Z Standard Dev: ' num2str(variableCamSolutionMeta.solutionSTD(3))])
                disp(['Azimuth Standard Dev: ' num2str(rad2deg(variableCamSolutionMeta.solutionSTD(4))) ' deg'])
                disp(['Tilt Standard Dev: ' num2str(rad2deg(variableCamSolutionMeta.solutionSTD(5))) ' deg'])
                disp(['Swing Standard Dev: ' num2str(rad2deg(variableCamSolutionMeta.solutionSTD(6))) ' deg'])

                f2=figure;
                f2.Position(4) = 1.5*f2.Position(4);
                f2.Position(3) = 2*f2.Position(4);

                % XCoordinate
                subplot(6,1,1)
                plot(t,extrinsics(:,1)-extrinsics(1,1))
                ylabel('\Delta x [m]')
                title(['Change in Extrinsics over Collection - ' char(string(extract_Hz(hh))) 'Hz'])

                % YCoordinate
                subplot(6,1,2)
                plot(t,extrinsics(:,2)-extrinsics(1,2))
                ylabel('\Delta y [m]')

                % ZCoordinate
                subplot(6,1,3)
                plot(t,extrinsics(:,3)-extrinsics(1,3))
                ylabel('\Delta z [m]')

                % Azimuth
                subplot(6,1,4)
                plot(t,rad2deg(extrinsics(:,4)-extrinsics(1,4)))
                ylabel('\Delta Azimuth [^o]')

                % Tilt
                subplot(6,1,5)
                plot(t,rad2deg(extrinsics(:,5)-extrinsics(1,5)))
                ylabel('\Delta Tilt[^o]')

                % Swing
                subplot(6,1,6)
                plot(t,rad2deg(extrinsics(:,6)-extrinsics(1,6)))
                ylabel('\Delta Swing [^o]')

                for k=1:6
                    subplot(6,1,k)
                    grid on
                    datetick
                end
                print(f2, '-dpng', fullfile(odir, 'Processed_data', ['scp_time_' char(string(extract_Hz(hh))) 'Hz.png']))

            end % for hh = 1 : length(extract_Hz)

        end % if ind_scp_method == 1


        if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Extrinsics through time DONE'])
        end
    end % for ff = 1 : length(flights)
end % for dd = 1:length(data_files)
clearvars -except *_dir user_email data_files
cd(global_dir)


%% Functions

function [currPoints, currFeatures, indexPairs] = helperDetectAndMatchFeatures(prevFeatures, I, cutoff, numPoints, ~)
% Detect and extract features from the current image.
currPoints   = detectSURFFeatures(I(cutoff:end,:), 'MetricThreshold', 500);currPoints.Location(:,2)=currPoints.Location(:,2)+cutoff;
if contains('UniformTag', 'On')
    currPoints   = selectUniform(currPoints, numPoints, size(I));
end
currFeatures = extractFeatures(I, currPoints);

% Match features between the previous and current image.
indexPairs = matchFeatures(prevFeatures, currFeatures, 'Unique', true, 'MaxRatio', 0.9);
end

function [tform, inlierIdx, scaleRecovered, thetaRecovered] = helperEstimateRotation(matchedPoints1, matchedPoints2)

if ~isnumeric(matchedPoints1)
    matchedPoints1 = matchedPoints1.Location;
end

if ~isnumeric(matchedPoints2)
    matchedPoints2 = matchedPoints2.Location;
end


[tform, inlierIdx] = estgeotform2d(matchedPoints2, matchedPoints1,'rigid');


invTform = invert(tform);
Ainv = invTform.A;

ss = Ainv(1,2);
sc = Ainv(1,1);
scaleRecovered = hypot(ss,sc);
%disp(['Recovered scale: ', num2str(scaleRecovered)])

% Recover the rotation in which a positive value represents a rotation in
% the clockwise direction.
thetaRecovered = atan2d(-ss,sc);
%disp(['Recovered theta: ', num2str(thetaRecovered)])

end

function [relPose, inlierIdx] = helperEstimateRelativePose(matchedPoints1, matchedPoints2, intrinsics)

if ~isnumeric(matchedPoints1)
    matchedPoints1 = matchedPoints1.Location;
end

if ~isnumeric(matchedPoints2)
    matchedPoints2 = matchedPoints2.Location;
end

for i = 1:100
    % Estimate the essential matrix.
    [E, inlierIdx] = estimateEssentialMatrix(matchedPoints1, matchedPoints2,...
        intrinsics);

    % Make sure we get enough inliers
    if sum(inlierIdx) / numel(inlierIdx) < .3
        continue;
    end

    % Get the epipolar inliers.
    inlierPoints1 = matchedPoints1(inlierIdx, :);
    inlierPoints2 = matchedPoints2(inlierIdx, :);

    % Compute the camera pose from the fundamental matrix. Use half of the
    % points to reduce computation.
    [relPose, validPointFraction] = ...
        estrelpose(E, intrinsics, inlierPoints1,...
        inlierPoints2);

    % validPointFraction is the fraction of inlier points that project in
    % front of both cameras. If the this fraction is too small, then the
    % fundamental matrix is likely to be incorrect.
    if validPointFraction > .7
        return;
    end
end

% After 100 attempts validPointFraction is still too low.
error('Unable to compute the Essential matrix');

end

function [scp] = redo_SCP(scp, In, scpUVd_old)
hGCP=figure(100);clf
imshow(In)
hold on
scatter(scpUVd_old(1), scpUVd_old(2), 50, 'y', 'LineWidth', 3)

xlim([scpUVd_old(1)-50 scpUVd_old(1)+50])
ylim([scpUVd_old(2)-50 scpUVd_old(2)+50])

prev_radius = scp.R;
h=rectangle('position',[scpUVd_old(1)-prev_radius, scpUVd_old(2)-prev_radius, 2*prev_radius, 2*prev_radius],'EdgeColor','r','linewidth',1);

while true
    new_radius = double(string(inputdlg({'Area of Interest Size'}, 'Click Enter with previous radius to finish.',1, {num2str(prev_radius)})));
    if new_radius ~= prev_radius
        delete(h)
        h=rectangle('position',[scpUVd_old(1)-new_radius,scpUVd_old(2)-new_radius,2*new_radius,2*new_radius],'EdgeColor','r','linewidth',1);
        prev_radius = new_radius;
    else
        break;
    end % if new_radius ~= prev_radius
end % while true
scp.R = prev_radius;

% ========================threshold============================================

I_gcp = In(round(scpUVd_old(2)-scp.R):round(scpUVd_old(2)+scp.R), round(scpUVd_old(1)-scp.R):round(scpUVd_old(1)+scp.R), :);
hIN = figure(2);clf
hIN.Position(3)=3*hIN.Position(4);
subplot(121)
imshow(rgb2gray(I_gcp))
colormap jet
hold on
colorbar; caxis([0 256]);
answer = questdlg('Bright or dark threshold', ...
    'Threshold direction',...
    'bright', 'dark', 'bright');
scp.brightFlag = answer;
subplot(122)

prev_threshold = 100;
switch answer
    case 'bright'
        mask = rgb2gray(I_gcp) > prev_threshold;
    case 'dark'
        mask = rgb2gray(I_gcp) < prev_threshold;
end
[rows, cols] = size(mask);
[y, x] = ndgrid(1:rows, 1:cols);
centroid = mean([x(mask), y(mask)]);
imshow(mask)
colormap jet
hold on
plot(centroid(1), centroid(2), 'w+', 'MarkerSize', 10);

while true
    new_threshold = double(string(inputdlg({'Threshold'}, 'Click Enter with previous threshold to finish.',1, {num2str(prev_threshold)})));
    if new_threshold ~= prev_threshold
        cla
        switch answer
            case 'bright'
                mask = rgb2gray(I_gcp) > new_threshold;
            case 'dark'
                mask = rgb2gray(I_gcp) < new_threshold;
        end
        if length(x(mask)) == 1
            centroid(1)=x(mask);
        else
            centroid(1) = mean(x(mask));
        end
        if length(y(mask)) == 1
            centroid(2)=y(mask);
        else
            centroid(2) = mean(y(mask));
        end
        imshow(mask)
        colormap jet
        hold on
        plot(centroid(1), centroid(2), 'w+', 'MarkerSize', 10);
        prev_threshold = new_threshold;
    else
        break;
    end % if new_threshold ~= prev_threshold
end % while true
scp.T = prev_threshold;
close(hIN)
close(hGCP)

end

% Callback function for the pause button

function pauseLoop(src, ~)
if strcmp(get(src, 'UserData'), 'pause')
    set(src, 'UserData', 'resume', 'String', 'Pause');
else
    set(src, 'UserData', 'pause', 'String', 'Resume');
end
end
