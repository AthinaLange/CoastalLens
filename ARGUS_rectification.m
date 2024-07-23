%% ARGUS_automated_rectification toolbox
%   1. Housekeeping
%           Global Directory Selection: Asks the user to choose the root directory for UAV rectification.
%           Directory Checking: Checks if required code directories and MATLAB toolboxes exist, prompting the user to download them if not. Adds required code directories to MATLAB's search path
%           Folder Selection: Allows the user to choose which days to process.
%   2. User Input Section
%           Camera Intrinsics: User inputs camera intrinsics file and related details.
%           Products Definition: User inputs or loads grid and transect coordinates.
%           Initial Camera Extrinsics: Use ground control points to define camera world pose.
%   3. Create Products
%           Pixel Extraction: Stabilize image and extract pixels for Products.
%           ARGUS Products: Create Timex, Bright, Dark products
%   4. Save Products (optional)
%           Save all rectified images as PNGs.
%
%% Description
%
%   Returns:
%           R (structure) : extrinsics/intrinsics information
%                       intrinsics (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%                       I (uint8 image) : undistorted initial frame
%                       world_gcp (double) : [n x 3] ground control location in world coordinate frame (x,y,z)
%                       image_gcp (double) : [n x 2] ground control location in inital frame
%                       worldPose (rigidtform3d) : orientation and location of camera in world coordinates, based off ground control location (pose, not extrinsic)
%           Products (structure) : Data products
%                       type (string) : 'Grid', 'xTransect', 'yTransect'
%                       frameRate (double) : frame rate of product (Hz)
%                       lat (double) : latitude of origin grid
%                       lon (double): longitude of origin grid
%                       angle (double): shorenormal angle of origid grid (degrees CW from North)
%                       xlim (double): [1 x 2] cross-shore limits of grid (+ is offshore of origin) (m)
%                       ylim (double) : [1 x 2] along-shore limits of grid (+ is to the right of origin looking offshore) (m)
%                       dx (double) : Cross-shore resolution (m)
%                       dy (double) : Along-shore resolution (m)
%                       x (double): Cross-shore distance from origin (+ is offshore of origin) (m)
%                       y (double): Along-shore distance from origin (+ is to the right of the origin looking offshore) (m)
%                       z (double) : Elevation - can be empty, assigned to tide level, or array of DEM values (NAVD88 m)
%                       t (datetime array) : [1 x m] datetime of images at given extraction rates in UTC
%                       localX (double) : [y_length x x_length] x coordinates in locally-defined coordinate system
%                       localY (double) : [y_length x x_length] y coordinates in locally-defined coordinate system
%                       localZ (double) : [y_length x x_length] z coordinates in locally-defined coordinate system
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
%
%
%% Function Dependenies
%
%% Required Toolbox
%   - Image Processing Toolbox
%   - Computer Vision Toolbox
%   - Lidar Toolbox (for pointcloud option)
%
%   - ffmpeg (https://ffmpeg.org)
%   - exiftool (https://exiftool.org)
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jan 2024;

%% ====================================================================
%                          Housekeeping
%                           - confirm CODES path
%                           - confirm DATA path - which day or multiple days are you processing
%                           - get user email
%  =====================================================================
%% =============== Get global directory location. ============================
clearvars

if ismac
    platform = 'Currently running on a Mac OS.';
elseif isunix
    platform = 'Currently running on a Linux OS.';
elseif ispc
    platform = 'Currently running on a Windows OS.';
else
    platform = 'Platform not supported';
end
disp(platform)

if ismac
    disp('Choose global (repository) folder - ''CoastalLens_ARGUS''.')
    setenv('PATH', [getenv('PATH') ':/usr/local/bin']);
end
global_dir = uigetdir('.', 'Choose global (repository) folder - ''CoastalLens_ARGUS'''.');
cd(global_dir)

%% =============== Check that all necessary codes are loaded. =================
code_dir = fullfile(global_dir, 'CODES');
% Check that scripts are downloaded.
if ~exist(fullfile(code_dir, 'scripts'), 'dir')
    disp('Please download scripts folder from GitHub.')
end
% Check that basic Functions are downloaded.
if ~exist(fullfile(code_dir, 'basicFunctions'), 'dir')
    disp('Please download basicFunctions folder from GitHub.')
end
% Check that helper Functions are downloaded.
if ~exist(fullfile(code_dir, 'helperFunctions'), 'dir')
    disp('Please download helperFunctions folder from GitHub.')
end

addpath(genpath(code_dir))

if isToolboxAvailable('Image Processing Toolbox','warning')== 0
    disp('Please install the Image Processing Toolbox before proceeding.')
end % if isToolboxAvailable('Image Processing Toolbox','warning')== 0

if isToolboxAvailable('Computer Vision Toolbox','warning')== 0
    disp('Please install the Computer Vision Toolbox before proceeding.')
end % if isToolboxAvailable('Computer Vision Toolbox','warning')== 0

if isToolboxAvailable('Lidar Toolbox','warning')== 0
    disp('Please install the Lidar Toolbox before proceeding.')
end % if isToolboxAvailable('Computer Vision Toolbox','warning')== 0

warning('off', 'images:geotrans:transformationMatrixBadlyConditioned')
clear *answer ans
%% =============== Select days to process.  ================================
% Load which data folders are to be processed
if ismac || isunix
    disp('Choose DATA folder.')
end
data_dir = uigetdir('.', 'DATA Folder');

% Load in all days that need to be processed.
day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
day_files(contains({day_files.name}, 'GCP'))=[]; day_files(contains({day_files.name}, 'Make_products'))=[];
day_files(contains({day_files.name}, 'Processed_data'))=[];day_files(contains({day_files.name}, 'Products'))=[];

if ~exist(fullfile(data_dir, 'Processed_data'), 'dir')
    mkdir(fullfile(data_dir, 'Processed_data'))
end %  if ~exist(fullfile(data_dir, 'Processed_data'), 'dir')
%% =============== Removes any days already processed. =====================
input_answer = questdlg('Do you want to process only new files?','New files?', 'Yes', 'No - Reprocess Everythin', 'Yes');
switch input_answer
    case 'Yes'
        processed_files = dir(fullfile(data_dir, 'Processed_data')); processed_files([processed_files.isdir] == 1)=[];
        processed_files(~contains({processed_files.name}, 'Products'))=[];
        % if file already processed - don't reprocess
        if ~isempty(processed_files)
            for ii = length(day_files):-1:1
                if contains([processed_files.name], day_files(ii).name)
                    day_files(ii) = [];
                end
            end
        end
end
%% =============== Confirm update emails and get email address. ===============
% Get user email
camera_type = 'ARGUS';
answer = questdlg('Recieve update emails?', 'Confirmation Emails?', 'Yes', 'No', 'Yes');
switch answer
    case 'Yes'
        user_email = inputdlg({'Name', 'Email'});

        props = java.lang.System.getProperties;
        props.setProperty('mail.smtp.port', '587');
        props.setProperty('mail.smtp.auth','true');
        props.setProperty('mail.smtp.starttls.enable','true');

        setpref('Internet','SMTP_Server','smtp.gmail.com');
        setpref('Internet','SMTP_Username','coastallens1903');
        setpref('Internet', 'SMTP_Password', 'krrq pufl tqcp hjrw')
        sendmail(user_email{2}, 'CoastalLens test email', [user_email{1} ' is processing ARGUS data from ' {day_files.name} ''])

        save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'day_files', 'user_email')
    case 'No'
        save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'day_files', 'camera_type')

end

%% =============== Get World Pose - do once otherwise load in data. ============
disp('How many cameras are you processing?')
cam_num = str2double(string(inputdlg('How many cameras?')));
disp('Have you processed a WorldPose for this camera?')
input_answer = questdlg('Have you processed a WorldPose for this camera?','WorldPose', 'Yes - Load it', 'No - Create Now', 'Yes - Load it');
switch input_answer
    case 'Yes - Load it'
        disp('Load in WorldPose - ARGUS2.mat.')
        [temp_file, temp_file_path] = uigetfile(global_dir, 'WorldPose');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*
    case 'No - Create Now'
        mop_num = str2double(string(inputdlg('MOP Origin')));
        [origin_grid] = get_origin(mop_num);
        %process_ig8_output_athina

        close all
        disp('Load in Calibration File - ARGUS2_CALIB.mat')
        [temp_file, temp_file_path] = uigetfile(global_dir, 'Calibration File');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*

        [world_camera] = select_target_gcp;
        for cc = 1:cam_num
            clear image_fig image_gcp world_gcp worldPose
            eval([strcat('R(cc).cameraParams = cameraParams_CAM', string(cc), ';')])

            sprintf('Load in Camera %i frame with GCPs visible.', cc)
            [temp_file, temp_file_path] = uigetfile({'.png'; '.jpg', '.tiff'}, 'Camera Frame with GCP');

            R(cc).I = undistortImage(imread(fullfile(temp_file_path, temp_file)), R(cc).cameraParams);
            image_fig = figure(1);clf
            [image_gcp] = select_image_gcp(R(cc).I, image_fig);

            [world_gcp] = select_target_gcp;

            worldPose = estworldpose(image_gcp,world_gcp, R(cc).cameraParams.Intrinsics, 'MaxReprojectionError',5);
            %worldPose.Translation = world_camera(cc,:);

            R(cc).image_gcp = image_gcp;
            R(cc).world_gcp = world_gcp;
            R(cc).worldPose = worldPose;
            hGCP = figure(cc);clf
            imshow(R(cc).I)
            hold on
            scatter(image_gcp(:,1), image_gcp(:,2), 100, 'r', 'filled')
            for ii = 1:length(image_gcp)
                text(image_gcp(ii,1)+25, image_gcp(ii,2)-25, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
            end % for ii = 1:length(image_gcp)
            iP = world2img(world_gcp,pose2extr(R(cc).worldPose),R(cc).cameraParams.Intrinsics);
            scatter(iP(:,1), iP(:,2), 50, 'y', 'LineWidth', 3)
        end

        save_dir = uigetdir('.', 'Choose where you want to save worldPose file.');
        save(fullfile(global_dir, 'CPG_Data', 'ARGUS2.mat'), 'R')
        info = inputdlg({'Filename to be saved'});
        disp('Location where worldPose file to be saved.')
        temp_file_path = uigetdir(global_dir, 'worldPose file save location');

        save(fullfile(temp_file_path, [info{1} '.mat']), 'R', 'origin_grid', 'cam_num')
end % switch input_answer
%% =============== Products. ============================================

answer = questdlg('Do you have a .mat Products file?', 'Product file', 'Yes', 'No', 'Yes');
switch answer
    case 'Yes'
        disp('Please select file of products you want to load in.')
        [temp_file, temp_file_path] = uigetfile(global_dir, 'Product file');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*

        if ~exist('Products', 'var')
            disp('Please create Products file.')
            [Products] = user_input_products(global_dir);
        end % if ~exist('Products', 'var')
    case 'No'
        [Products] = user_input_products(global_dir);
end % switch answer
clear answer

%% =============== DEM. ================================================
%                          Load in topography DEM
%                           - Requires time, X, Y, Z data in world coordinates
%  ==============================================================================
if ~exist('DEM', 'var')
    answer = questdlg('Do you want to use a topography DEM?', 'Topo DEM', 'Yes', 'No', 'Yes');
    switch answer
        case 'Yes'
            answer2 = questdlg('Do you have a topography DEM?', 'Topo DEM', 'Yes', 'No', 'Yes');
            switch answer2
                case 'Yes'
                    disp('Please load in DEM topo file.')
                    [temp_file, temp_file_path] = uigetfile(global_dir, 'DEM topo file');
                    load(fullfile(temp_file_path, temp_file)); clear temp_file*
                    assert(isfield(DEM, 'time'), 'Error (input_day_flight_data.m): DEM does not have time field.')
                    assert(isfield(DEM, 'X_gridded'), 'Error (input_day_flight_data.m): DEM does not have X_gridded field.')
                    assert(isfield(DEM, 'Y_gridded'), 'Error (input_day_flight_data.m): DEM does not have Y_gridded field.')
                    assert(isfield(DEM, 'Z_gridded'), 'Error (input_day_flight_data.m): DEM does not have Z_gridded field.')
                case 'No'
                    [DEM] = define_DEM;
                    answer4 = questdlg('Do you want to save this DEM file for the future?', 'Save DEM file', 'Yes', 'No', 'Yes');
                    switch answer4
                        case 'Yes'
                            info = inputdlg({'Filename to be saved'});
                            disp('Location where DEM file to be saved.')
                            temp_file_path = uigetdir(global_dir, 'DEM file save location');
                            save(fullfile(temp_file_path, [info{1} '.mat']), 'DEM')
                    end % switch answer4
            end
            [~,date_id]=min(abs(datetime(str2double(strcat(day_files(dd).name(1:10), '.', day_files(dd).name(11:end))), 'ConvertFrom', 'posixtime')-[DEM.time]));
            DEM = DEM(date_id);
    end
end
%% =============== productsCheck. =======================================
%                          CHECK PRODUCTS ON INITIAL IMAGE
%                           - Load in all required data -
%                             extrinsics, intrinsics, initial frame, input data, products
%  =====================================================================
[Products.tide] = deal(0);
for cc = 1:cam_num

    [xyz,~,~,~,~,~] = getCoords(Products(1));
    [y2,x2, ~] = ll_to_utm(Products(1).lat, Products(1).lon);

    %aa=xyz-[x2 y2 0];
    %id_origin=find(min(abs(aa(:,[1 2])))==abs(aa(:,[1 2])));
    %iP = round(world2img(xyz, pose2extr(R(cc).worldPose), R(cc).cameraParams.Intrinsics));
    %iP_origin = iP(id_origin);
    clear aa iP

    aa=xyz-[R(cc).worldPose.Translation(1) R(cc).worldPose.Translation(2) 0];
    % This is built in for Fletcher - might not be valid for other sites
    if Products(1).angle > 180
        if cc == 1
            id=[];
            % behind camera
            for ii = 1:length(aa)
                if aa(ii,1) > 0 & aa(ii,2) < 0
                    id = [id ii];
                end
            end
            % left of camera
            for ii = 1:length(aa)
                if aa(ii,1) < 0 & aa(ii,2) < 0
                    id = [id ii];
                end
            end

        elseif cc == 2
            id=[];
            % behind camera
            for ii = 1:length(aa)
                if aa(ii,1) > 0 & aa(ii,2) > 0
                    id = [id ii];
                end
            end

            % right of camera
            for ii = 1:length(aa)
                if aa(ii,1) < 0 & aa(ii,2) > 0
                    id = [id ii];
                end
            end
        end

        xyz(id,:)=[];
    end
    aa=xyz-[R(cc).worldPose.Translation(1) R(cc).worldPose.Translation(2) 0];

    iP = round(world2img(xyz, pose2extr(R(cc).worldPose), R(cc).cameraParams.Intrinsics));

    figure(cc);clf
    imshow(R(cc).I)
    hold on
    title('Grid')
    scatter(iP(:,1), iP(:,2), 25,'r', 'filled')
    xlim([0 size(R(cc).I,2)])
    ylim([0 size(R(cc).I,1)])

    id=find(min(abs(aa(:,[1 2])))==abs(aa(:,[1 2])));
    scatter(iP(id(1),1), iP(id(1),2),50, 'g', 'filled')
    legend('Grid', 'Origin')
    set(gca, 'FontSize', 20)
end
%% =============== x_transects. ==========================================
for cc = 1:cam_num
    clear Products_x
    plot_xtransects(Products, R(cc).I, R(cc).cameraParams.Intrinsics, R(cc).worldPose)
    set(legend, 'Location', 'eastoutside')
    pause(1)
end
%% =============== y_transects. ==========================================
for cc = 1:cam_num
    plot_ytransects(Products, R(cc).I, R(cc).cameraParams.Intrinsics, R(cc).worldPose)
    set(legend, 'Location', 'eastoutside')
    pause(1)
end
%% =============== get Rectified Products. ==================================
close all

for dd = 1:length(day_files)
    tic
    cd(fullfile(day_files(dd).folder, day_files(dd).name))
    time=datetime(str2double(strcat(day_files(dd).name(1:10), '.', day_files(dd).name(11:end))), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    [~,~,verified,~,~] = getNOAAtide(time, time+minutes(20),'9410230');
    [Products.t] = deal(time);
    [Products.tide]=deal(mean(verified));
    for cc = 1:cam_num
        if isfield(Products, 'iP')
            Products = rmfield(Products, 'iP');
        end

        if isfield(Products, 'Irgb_2d')
            Products = rmfield(Products, 'Irgb_2d');
        end
        for pp = 1 : length(Products)
            if exist('DEM', 'var')
                disp('Running with DEM.')
                [xyz, localX, localY, Z, Eastings, Northings] = getCoords_DEM(Products(pp), DEM);
            else
                [xyz, localX, localY, Z, Eastings, Northings] = getCoords(Products(pp));
            end
            aa=xyz-[R(cc).worldPose.Translation(1) R(cc).worldPose.Translation(2) 0];

            % if cc == 1
            %     id=[];
            %     % behind camera
            %     for ii = 1:length(aa)
            %         if aa(ii,1) > 0 & aa(ii,2) < 0
            %             id = [id ii];
            %         end
            %     end
            %     % left of camera
            %     for ii = 1:length(aa)
            %         if aa(ii,1) < 0 & aa(ii,2) < 0
            %             id = [id ii];
            %         end
            %     end
            % 
            % elseif cc == 2
            %     id=[];
            %     % behind camera
            %     for ii = 1:length(aa)
            %         if aa(ii,1) > 0 & aa(ii,2) > 0
            %             id = [id ii];
            %         end
            %     end
            % 
            %     % right of camera
            %     for ii = 1:length(aa)
            %         if aa(ii,1) < 0 & aa(ii,2) > 0
            %             id = [id ii];
            %         end
            %     end
            % end

            Products(pp).xyz = xyz;
            Products(pp).localX = localX;
            Products(pp).localY = localY;
            Products(pp).Eastings = Eastings;
            Products(pp).Northings = Northings;
            Products(pp).localZ = Z;
        end

        oname = strcat('ARGUS2_Cam', string(cc),'_', day_files(dd).name);
        disp(oname)

        for pp = 1:length(Products)
            Products(pp).iP = round(world2img(Products(pp).xyz, pose2extr(R(cc).worldPose), R(cc).cameraParams.Intrinsics));
            %Products(pp).iP(id,:)=NaN;
        end

        images = imageDatastore(fullfile(day_files(dd).folder, day_files(dd).name));
        eval([strcat('images.Files = images.Files(contains(images.Files, ''Cam', string(cc), '''));')])

        for viewId = 1:length(images.Files)
            tic
            I = undistortImage(readimage(images, viewId), R(cc).cameraParams.Intrinsics);
            for pp = 1:length(Products)
                clear Irgb_temp
                for ii = 1:length(Products(pp).iP)
                    if any(isnan(Products(pp).iP(ii,:))) || any(Products(pp).iP(ii,:) <= 0) || any(Products(pp).iP(ii,[2 1]) >= size(I, [1 2]))
                        Irgb_temp(ii, :) = uint8([0 0 0]);
                    else
                        Irgb_temp(ii, :) = I(Products(pp).iP(ii,2), Products(pp).iP(ii,1),:);
                    end % if any(Products(pp).iP(ii,:) <= 0) || any(Products(pp).iP(ii,[2 1]) >= size(I))
                end %  for ii = 1:length(Products(pp).iP)

                if contains(Products(pp).type, 'Grid')
                    Products(pp).Irgb_2d(viewId, :,:,:) = reshape(Irgb_temp, size(Products(pp).localX,1), size(Products(pp).localX,2), 3);
                else
                    Products(pp).Irgb_2d(viewId, :,:) = Irgb_temp;
                end % if contains(Products(pp).type, 'Grid')

            end
            toc
        end
        
        save(fullfile(data_dir, 'Processed_data', strcat(oname, '_Products')),'Products', 'cam_num', '-v7.3')
        toc
         if contains(Products(1).type, 'Grid')
            IrIndv(:,:,:,cc) = squeeze(Products(1).Irgb_2d(1,:,:,:));
         end
    end % for cc = 1 : 2 % Cam 1 or 2
    
    if sum(IrIndv(:)) ~= 0 % some color values present
        [Ir] =cameraSeamBlend(IrIndv);
        figure(1);clf
        image(Products(1).localX(:), Products(1).localY(:), Ir)
        axis equal
        xlim([min(Products(1).xlim) max(Products(1).xlim)])
        ylim([min(Products(1).ylim) max(Products(1).ylim)])
        set(gca, 'FontSize', 16)
        set(gcf, 'Units', 'Normalized', 'OuterPosition', [0, 0.04, 0.5, 0.96]);
        xlabel('Cross-shore Distance (m)')
        ylabel('Along-shore Distance (m)')
        title({day_files(dd).name, strcat(string(time), ' UTC')})
        saveas(gcf, fullfile(data_dir, 'Processed_data', strcat('ARGUS_', day_files(dd).name, '_Grid.png')))
    end
        Products = rmfield(Products, 'iP');
end % for dd = 1:length(day_files)
%% =============== save timestacks. ======================================
save_timestacks_ARGUS

%% =============== cBathy. ==============================================

close all
for  dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    % repeat for each flight
    for cc = 1:2
        oname = strcat('ARGUS2_Cam', string(cc),'_', day_files(dd).name);
        disp(oname)

        load(fullfile(data_dir, 'Processed_data', strcat(oname, '_Products.mat')), 'Products')
        assert(isa(Products, 'struct'), 'Error (run_cBathy): Products must be a stucture as defined in user_input_products.')
        assert((isfield(Products, 'type') && isfield(Products, 'frameRate')), 'Error (run_cBathy): Products must be a stucture as defined in user_input_products.')

        ids_grid = find(ismember(string({Products.type}), 'Grid'));
        for pp = ids_grid % repeat for all grids
            clear Xout Yout Zout Igray
            %% run cBathy 2.0
            for viewId = 1:size(Products(pp).Irgb_2d,1)
                Igray(:,:,viewId) = im2gray(squeeze(Products(pp).Irgb_2d(viewId, :,:,:)));
            end
            % Remove Nans
            [r c tt]=size(Igray);
            for k=1:r
                for j=1:c
                    bind =find(isnan(Igray(k,j,:))==1);
                    gind =find(isnan(Igray(k,j,:))==0);
                    Igray(k,j,bind)=nanmean(Igray(k,j,gind));
                end
            end
            if Products(pp).angle < 180 % East Coast
                Xout = Products(pp).localX;
                Yout = Products(pp).localY;
            elseif Products(pp).angle >180 % West Coast
                Xout=-(Products(pp).localX.*cosd(180)+Products(pp).localY.*sind(180));
                Yout=-(Products(pp).localY.*cosd(180)-Products(pp).localX.*sind(180));
            end % if Products(pp).angle < 180 % East Coast
            Zout = Products(pp).localZ;

            %Demo Plot
            figure(1);clf
            subplot(121)
            pcolor(Products(pp).localX,Products(pp).localY,Igray(:,:,1))
            shading flat
            set(gca, 'XDir', 'reverse')
            title('Original localX/Y')
            subplot(122)
            pcolor(Xout,Yout, Igray(:,:,1))
            shading flat
            title('Rotated localX/Y - waves coming from east')

            [~,cutoff_0]=min(abs(Yout(:,1)-0));
            if cc == 1
                Xout = Xout(cutoff_0:end,:);
                Yout = Yout(cutoff_0:end,:);
                Zout = Zout(cutoff_0:end,:);
                Igray = Igray(cutoff_0:end,:,:);
            elseif cc == 2
                Xout = Xout(1:cutoff_0,:);
                Yout = Yout(1:cutoff_0,:);
                Zout = Zout(1:cutoff_0,:);
                Igray = Igray(1:cutoff_0,:,:);
            end

            xyz=[Xout(:) Yout(:) Zout(:)];

            m = size(Igray,1);
            n = size(Igray,2);
            tt = size(Igray,3);
            data=zeros(tt,m*n);

            [xindgrid,yindgrid]=meshgrid(1:n,1:m);
            rowIND=yindgrid(:);
            colIND=xindgrid(:);

            for i=1:length(rowIND(:))
                data(:,i)=reshape(Igray(rowIND(i),colIND(i),:),tt,1);
            end

            %% Loading CIRN data
            clearvars -except dd *_dir user_email day_files cc pp ids_grid Products xyz data oname R

            % Fill in cam requirement
            cam=xyz.*0+1;

            % Get into Epoch time
            epoch=posixtime(Products(pp).t);
            %% cBathy Parameters
            % cBathyTideTorrey pulls from NOAA SIO tide gauge. If tide diccerent, use
            % diccerent function

            %%% Site-specific Inputs
            params.stationStr = oname;
            params.dxm = Products(pp).dx;%5;                    % analysis domain spacing in x
            params.dym = Products(pp).dy;%10;                    % analysis domain spacing in y
            params.xyMinMax = [min(xyz(:,1)) max(xyz(:,1)) min(xyz(:,2)) max(xyz(:,2))];   % min, max of x, then y
            % default to [] for cBathy to choose
            params.tideFunction = 'cBathyTideneutral';  % tide level function for evel

            %%%%%%%   Power user settings from here down   %%%%%%%
            params.MINDEPTH = 0.25;             % for initialization and final QC
            params.MAXDEPTH = 20;             % for initialization and final QC
            params.QTOL = 0.5;                  % reject skill below this in csm
            params.minLam = 12;                 % min normalized eigenvalue to proceed
            params.Lx = 25;%3*params.dxm;           % tomographic domain smoothing
            params.Ly = 50;%3*params.dym;           %
            params.kappa0 = 2;                  % increase in smoothing at outer xm
            params.DECIMATE = 1;                % decimate pixels to reduce work load.
            params.maxNPix = 80;                % max num pixels per tile (decimate excess)
            params.minValsForBathyEst = 4;

            % f-domain etc.
            params.fB = [1/18: 1/50: 1/4];		% frequencies for analysis (~40 dof)
            params.nKeep = 4;                   % number of frequencies to keep

            % debugging options
            params.debug.production = 0;
            params.debug.DOPLOTSTACKANDPHASEMAPS = 0;  % top level debug of phase
            params.debug.DOSHOWPROGRESS = 1;		  % show progress of tiles
            params.debug.DOPLOTPHASETILE = 0;		  % observed and EOF results per pt
            params.debug.TRANSECTX = 200;		  % for plotStacksAndPhaseMaps
            params.debug.TRANSECTY = 900;		  % for plotStacksAndPhaseMaps

            % default occshore wave angle.  For search seeds.
            params.occshoreRadCCWFromx = 0;
            params.nlinfit=1;
            %% Run Cbathy

            bathy.params = params;
            bathy.epoch  = num2str(epoch(1));
            bathy.sName  = oname;

            bathy = analyzeBathyCollect(xyz, epoch, (data), cam, bathy)
            figure
            bathy.params.debug.production=1;
            plotBathyCollect(bathy)
            sgtitle([oname])
            %%
            [Xo Yo]=meshgrid(bathy.xm,bathy.ym);

            if Products(pp).angle < 180 % East Coast

            elseif Products(pp).angle > 180 % West Coast
                Xo=-(Xo.*cosd(180)+Yo.*sind(180));
                Yo=-(Yo.*cosd(180)-Xo.*sind(180));
                bathy.fCombined.h = fliplr(bathy.fCombined.h);
                bathy.fCombined.hErr = fliplr(bathy.fCombined.hErr);
            end % if Products(pp).angle < 180 % East Coast

            bathy.coords.Xo = Xo; bathy.coords.Eout = Products(pp).Eastings;
            bathy.coords.Yo = Yo; bathy.coords.Nout = Products(pp).Northings;

            save(fullfile(odir, 'Processed_data', [oname '_cBathy']),'bathy', '-v7.3')

        end % for pp = ids_grid % repeat for all grids

        if exist('user_email', 'var')
            try
                sendmail(user_email{2}, [oname '- Rectifying Products DONE'])
            end
        end % if exist('user_email', 'var')
    end %  for cc = 1 : length(flights)
end % for  dd = 1 : length(day_files)
close all
cd(global_dir)
