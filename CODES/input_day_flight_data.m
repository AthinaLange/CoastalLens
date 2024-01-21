%% user_input_data
% User provides all required input data for UAV_automated_rectification toolbox
%
% 1. Test Email Confirmation
% 	Asks user if test email received, otherwise fix email SMTP server settings
% 2. Day-specific Data
%	    - check in input data already determined - and load in file if it exists.
% 	    - determine drone type, e.g. DJI or other - will help define video name
% 	    - determine timezone that the video was recorded in - assuming video metadata % 	   in local timezone, otherwise pick UTM
% 	    - choose intrinsics file for camera used on that day
% 	        if none exists, will prompt CameraCalibrator app
% 	    - choose Products to compute
% 		    - select from .mat file
% 		    - define in user_input_products.m
% 	    - determine image extraction rates based on frame rates needed for products
% 3. Flight-specific Data
% 	- if non-DJI, prompt for video naming convention
% 	- use exiftool to pull metadata from images and video
% 		convert Lat/Long to Eastings/Northings
% 	- extract first frame to do initial calibration on
% 	- check that distortion is correctly accounted for
% 	- use ground control points to obtain initial camera position and pose
% 		- Option 1: Automated with LiDAR survey
% 		- Option 2: Manual GCP selection from LiDAR or SfM survey
% 		- Option 3: Manual GCP selection from GoogleEarth
% 		- Option 4: Manual GCP selection from targets (QCIT)
% 		- Option 5: No GCP - use camera metadata
% 	   get CIRN extrinsics and MATLAB worldPose - if more points needed, user prompted
% 	- specify if you want to use SCPs or Feature Matching for image stabilization
%	    - if image stabilization via Feature Matching
% 	    - Extract images every 30sec from all videos (using VideoReader)
% 	    - Determine how much of image area should be useable for feature matching (how much beach) - improves code speed
% 	    - Does 2D warping for relative movement between frames (depending on how much rotation is needed, decide between 2D or 3D)
%     - if image stabilization via SCPs (QCIT)
% 	    - Define SCPs (using same points as GCP targets) - define radius, bright/dark, and threshold - specify elevation
%	    - plot rectified grid products and project xTransects and yTransects into oblique image and confirm that product locations/dimensions are correct
% 	- send email with determined information
% 		- origin coordinates
% 		- initial extrinsics guess
% 		- gcp-corrected extrinsics with method note
% 		- MATLAB worldPose and image stabilization method (2D, 3D, SCP)
% 		- frame rate of data
% 		- Products to produce
% 		- images
%
%
%
% REQUIRES: exiftool installation (https://exiftool.org/)
% Code dependencies:
% 	- user_input_products
% 	- intg2012b
% 	- ll_to_utm
%	    - get_noaa_lidar
%	    - get_local_survey
%	    - select_image_gcp
%	    - select_target_gcp
% 	- select_survey_gcp
% 	- CIRN2MATLAB
% 	- get_coarse_pose_estimation
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Dec 2023
%

%% ===========================testEmail=========================================
%                  Confirm test email recieved
%                   - TODO Change setting for SMTP server
%  =====================================================================
answer = questdlg('Did you get the test email?','Test email check', 'Yes / Don''t want it', 'No', 'Yes / Don''t want it');
switch answer
    case 'No'
        disp('Please check email settings to proceed.')
        user_email = inputdlg({'Name', 'Email'});

        props = java.lang.System.getProperties;
        props.setProperty('mail.smtp.port', '587');
        props.setProperty('mail.smtp.auth','true');
        props.setProperty('mail.smtp.starttls.enable','true');

        setpref('Internet','SMTP_Server','smtp.gmail.com');
        setpref('Internet','SMTP_Username','athinalange1996');
        setpref('Internet', 'SMTP_Password', 'baundwhnctgbsykb')
        sendmail(user_email{2}, 'UAV Toolbox test email', [user_email{1} ' is processing UAV data from ' day_files.name '.'])

        return
end
%% ===========================userInput=========================================
%                          USER INPUT
%                           - Obtain day relevant data
%                               - drone type
%                               - timezone
%                               - camera intrinsics
%                               - Products
%                               - extraction frame rates
%                           - Do flight specific checks
%                               - Pull initial drone position and pose from metadata (using exiftool)
%                               - extract initial frame (using ffmpeg)
%                               - confirm distortion
%                               - confirm inital drone position and pose from gcps
%                               - specify if image stabilization done with Feature Matching or SCPs
%                                   - with SCPs - define radius and thresholds
%                               - check products
%  ===============================================================================
for dd = 1 : length(day_files)
    %% ==========================Housekeeping======================================
    clearvars -except dd *_dir user_email day_files
    cd([day_files(dd).folder '/' day_files(dd).name])
    %% ==========================inputData==========================================
    %                                                    Load in input_data if already specified
    %  =============================================================================

    % Check if user already has input file with all general drone / products information
    disp('For CPG: ''day_input_data.mat'' in day files.')
    input_answer = questdlg('Do you have a .mat input data file?','Input Data File', 'Yes', 'No', 'No');
    switch input_answer
        case 'Yes'
            disp('Load in day input file.')
            disp('For CPG: ''day_input_data.mat'' in day files.')
            [temp_file, temp_file_path] = uigetfile(global_dir, 'Input File');
            load(fullfile(temp_file_path, temp_file)); clear temp_file*
    end

    %% ==========================DroneType=========================================
    %                                                    Choose drone system
    %  =============================================================================
    if ~exist('drone_type', 'var') || ~isstring(drone_type)
        [ind_drone,tf] = listdlg('ListString',[{'DJI'}, {'Other'}], 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'What drone platform was used?'});
        if ind_drone == 1
            drone_type = "DJI";
        else
            drone_type = string(inputdlg({'What drone system?'}));
        end
    end
    %% ==========================TimeZone==========================================
    %                                        Choose timezone of video recordings
    %  =============================================================================
    if ~exist('tz', 'var') || ~ischar(tz)
        [tz] = select_timezone;
    end
    %% ==========================intrinsics===========================================
    %                                   Choose intrinsics file for each day of flight
    %  ==============================================================================
    if  (~exist('cameraParams_undistorted', 'var') && ~exist('cameraParams_distorted', 'var'))
        if ~exist('cameraParams', 'var')
            answer = questdlg('Has the camera been calibrated?', 'Camera Calibration', 'Yes', 'No', 'Yes');
            switch answer
                case 'Yes'
                    disp('Load in camera calibration file.')
                    disp('For CPG: under CPG_data/cameraParams_whitecap.mat') %% XXX
                    [temp_file, temp_file_path] = uigetfile(global_dir, 'Camera Parameters');
                    load(fullfile(temp_file_path, temp_file)); clear temp_file*
                case 'No'
                    disp('Please calibrate camera to proceed.')
                    cameraCalibrator
                    return
            end
            clear answer
        end
    end
    %% ==========================product============================================
    %                          DEFINE PRODUCT TYPE
    %                           - Do you already have a product file - as made from user_input_products.m
    %                               - If so, can load that in
    %                           - Define origin of grid and products to be made
    %  ==============================================================================
    if ~exist('Products', 'var') || ~isstruct(Products)
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
                    %construct_MOPS_DEM %% XXX
                    user_input_products
                end
            case 'No'
                user_input_products
        end
        clear answer
    end
    %% ==========================extractionRate=======================================
    %                          EXTRACTION FRAME RATES
    %                           - Find frame rates of products
    %                           - Find minimum sets of frame rates to satisfy product frame rates,
    %                             i.e. 2Hz data can be pulled from 10Hz images
    %  ==============================================================================
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
    %% ==========================saveDayData========================================
    %                          SAVE DAY RELEVANT DATA
    %                           - Save camera intrinsics, extraction frame rates, products, flights for specific day, drone type and timezone
    %  ==============================================================================
    flights = dir(fullfile(day_files(dd).folder, day_files(dd).name)); flights([flights.isdir]==0)=[]; flights(contains({flights.name}, '.'))=[]; flights(contains({flights.name}, 'GCP'))=[];
    switch input_answer
        case 'No'
            save(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'),...
                'cameraParams*', 'extract_Hz', 'Products', 'flights', 'drone_type', 'tz')
    end

    %% =============================================================================
    %                          PROCESS EACH FLIGHT
    %  ==============================================================================
    for ff = 1:length(flights)
        %% ========================Housekeeping=======================================
        clearvars -except dd ff *_dir user_email day_files flights
        load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'))

        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        cd(odir)
        if ~exist(fullfile(odir, 'Processed_data'), 'dir')
            mkdir 'Processed_data'
        end

        %% ========================metadata===========================================
        %                          INITIAL DRONE COORDINATES FROM METADATA
        %                           - Use exiftool to pull metadata from images and video
        %                               - mov_id indicates which movies to use in image extraction
        %                               - get inital camera position and pose from metadata
        %  ============================================================================
        if contains(drone_type, 'DJI')
            drone_file_name = 'DJI';
        else
            temp_name = string(inputdlg({'What is the file prefix?'}));
            drone_file_name = temp_name(1);
        end

        [C] = get_metadata(odir, oname, file_prefix = drone_file_name, save_dir = fullfile(odir, 'Processed_data'));

        [jpg_id] = find_file_format_id(C, file_format = 'JPG');
        [mov_id] = find_file_format_id(C, file_format = {'MOV', 'MP4'});

        % if image taken at beginning & end of flight - use beginning image
        if length(jpg_id) > 1; jpg_id = jpg_id(1); end
        % if no image taken, use mov_id
        if isempty(jpg_id); jpg_id = mov_id(1); end

        % CONFIRM VIDEOS TO PROCESS
        [id, ~] = listdlg('ListString', append(string(C.FileName(mov_id)), ' - ',  string(C.Duration(mov_id))), 'SelectionMode','multiple', 'InitialValue',[1:length(mov_id)], 'PromptString', {'What movies do you want' 'to use? (command + for multiple)'});
        mov_id = mov_id(id);

        % pull RTK-GPS coordinates from image and change to Eastings/Northings
        % requires intg2012b and ll_to_utm codes (in basic_codes)
        lat = char(C.GPSLatitude(jpg_id));
        lat = str2double(lat(1:10));
        long = char(C.GPSLongitude(jpg_id));
        if long(end) == 'W'
            long = str2double(['-' long(1:11)]);
        else
            long = str2double(long(1:11));
        end
        [zgeoid_offset] = intg2012b(code_dir, lat,long);
        [UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(lat, long);
        extrinsicsInitialGuess = [UTMEasting UTMNorthing C.AbsoluteAltitude(jpg_id)-zgeoid_offset deg2rad(C.CameraYaw(mov_id(1))+360) deg2rad(C.CameraPitch(mov_id(1))+90) deg2rad(C.CameraRoll(mov_id(1)))]; % [ x y z azimuth tilt swing]

        save(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'extrinsicsInitialGuess', 'UTMNorthing', 'UTMEasting', 'zgeoid_offset', 'jpg_id', 'mov_id', 'lat', 'long', 'C', 'tz')

        clearvars form i_temp  lat long zgeoid_offset UTMNorthing UTMEasting UTMZone
        %% ========================initialFrame=========================================
        %                          EXTRACT INITIAL FRAME
        %                           - Use ffmpeg tool to extract first frame to be used for distortion and product location check
        %  ============================================================================
        if ~exist(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'), 'file')
            system(['ffmpeg -ss 00:00:00 -i ' char(string(C.FileName(mov_id(1)))) ' -frames:v 1 -loglevel quiet -stats -qscale:v 2 Processed_data/Initial_frame.jpg']);
        end

        %% ========================distortion===========================================
        %                          CONFIRM DISTORTION
        %                           - If cameraParameters includes both a _distorted and _undistorted version
        %                               - show initial frame, initial frame corrected with _distorted and with _undistorted
        %                                 and confirm with user which distortion correction should be used.
        %                           - If cameraParameters includes only one calibration
        %                               - show initial frame and initial frame corrected with calibration
        %                                 and confirm with user that you are happy with calibration
        %                           - Save intrinsics fille in suitable format
        %  ============================================================================
        I = imread(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'));
        % if both a distorted and undistorted version of the codes exists
        if exist('cameraParams_distorted', 'var') & exist('cameraParams_undistorted', 'var')
            J1 = undistortImage(I, cameraParams_distorted);
            J2 = undistortImage(I, cameraParams_undistorted);
            hFig = figure(1);clf
            montage({I, J1, J2}, 'Size', [1 3])
            text(1/6, -0.05, 'Original 1st frame', 'FontSize', 14, 'Units', 'normalized', 'HorizontalAlignment','center')
            text(3/6, -0.05, 'Distortion Correction OFF', 'FontSize', 14, 'Units', 'normalized', 'HorizontalAlignment','center')
            text(5/6, -0.05, 'Distortion Correction ON', 'FontSize', 14, 'Units', 'normalized', 'HorizontalAlignment','center')

            [ind_distortion,tf] = listdlg('ListString',[{'Distorted (Off)'}, {'Undistorted (On)'}, {'Recalibrate Camera'}], 'SelectionMode','single', 'InitialValue',2, 'PromptString', {'Distortion correction On/Off?'});
            if ind_distortion == 1
                cameraParams = cameraParams_distorted;
                clf;imshowpair(I,J1, 'montage'); print(gcf, '-dpng', fullfile(odir, 'Processed_data', 'undistortImage_pair.png'))
                clf;imshow(J1); imwrite(J1, fullfile(odir, 'Processed_data', 'undistortImage.png'), 'png')
            elseif ind_distortion == 2
                cameraParams = cameraParams_undistorted;
                clf;imshowpair(I,J2, 'montage'); print(gcf, '-dpng', fullfile(odir, 'Processed_data', 'undistortImage_pair.png'))
                clf;imshow(J2); imwrite(J2, fullfile(odir, 'Processed_data', 'undistortImage.png'), 'png')
            elseif ind_distortion == 3
                disp('Please recalibrate camera or check that correct intrinsics file is used.')
                return
            end

            % if only 1 cameraParams version exists
        else
            J1 = undistortImage(I, cameraParams);
            hFig = figure(1);clf
            imshowpair(I,J1, 'montage')

            [ind_distortion,tf] = listdlg('ListString',[{'Correctly calibrated'}, {'Recalibrate Camera'}], 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Is the camera corrected calibrated?'});
            if ind_distortion == 1
                clf;imshowpair(I,J1, 'montage'); print(gcf, '-dpng', fullfile(odir, 'Processed_data', 'undistortImage_pair.png'))
                clf;imshow(J1); imwrite(J1, fullfile(odir, 'Processed_data', 'undistortImage.png'), 'png')
            elseif ind_distortion == 2
                disp('Please recalibrate camera or check that correct intrinsics file is used.')
                cameraCalibrator
                return
            end
        end
        % saving in CIRN format
        intrinsics_CIRN(1) = cameraParams.ImageSize(2);            % Number of pixel columns
        intrinsics_CIRN(2) = cameraParams.ImageSize(1);            % Number of pixel rows
        intrinsics_CIRN(3) = cameraParams.PrincipalPoint(1);         % U component of principal point
        intrinsics_CIRN(4) = cameraParams.PrincipalPoint(2);          % V component of principal point
        intrinsics_CIRN(5) = cameraParams.FocalLength(1);         % U components of focal lengths (in pixels)
        intrinsics_CIRN(6) = cameraParams.FocalLength(2);         % V components of focal lengths (in pixels)
        intrinsics_CIRN(7) = cameraParams.RadialDistortion(1);         % Radial distortion coefficient
        intrinsics_CIRN(8) = cameraParams.RadialDistortion(2);         % Radial distortion coefficient
        if length(cameraParams.RadialDistortion) == 3
            intrinsics_CIRN(9) = cameraParams.RadialDistortion(3);         % Radial distortion coefficient
        else
            intrinsics_CIRN(9) = 0;         % Radial distortion coefficient
        end
        intrinsics_CIRN(10) = cameraParams.TangentialDistortion(1);        % Tangential distortion coefficients
        intrinsics_CIRN(11) = cameraParams.TangentialDistortion(2);        % Tangential distortion coefficients

        if (exist('cameraParams_distorted', 'var') & exist('cameraParams_undistorted', 'var') ) && ind_distortion == 2
            intrinsics_CIRN(7:11) = 0; % no distortion (if distortion correction on)
        end

        intrinsics = cameraParams.Intrinsics;
        save(fullfile(odir, 'Processed_data', [oname '_IO']), 'intrinsics_CIRN', 'intrinsics', 'cameraParams', 'extrinsicsInitialGuess')
        clearvars I J1 J2 tf ind_distortion hFig cameraParams_*
        close all
        %% ========================GCPs==============================================
        %                          GET GCPs HERE (TODO)
        %                           - Option 1: Fully Automated from LiDAR points
        %        DONE                   - Option 2: Manual from hand selection from LiDAR or SfM (airborne or local)
        %                           - Option 3: Manual from hand selection from GoogleEarth
        %        DONE                   - Option 4: Manual from GCP targets
        %                           - Option 5: Use camera metadata
        %  ============================================================================
        % whichever method generates image_gcp (N x 2) and world_gcp (N x 3)
        % use process_ig8_output_athina to get gps_northings.txt
        I = imread( fullfile(odir, 'Processed_data', 'undistortImage.png'));

        [ind_gcp_option,~] = listdlg('ListString',[{'Automated from Airborne LiDAR (TBD)'}, {'Select points from LiDAR/SfM'}, {'Select points from GoogleEarth (TBD)'}, {'Select GCP targets'}, {'Use Metadata (TBD)'}],...
            'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Initial GCP Method'});

        if ind_gcp_option == 1 % automated from LiDAR
            gcp_method = 'auto_LiDAR';
            [ind_lidar_option,~] = listdlg('ListString',[{'Airborne LiDAR (TBD)'}, {'Local LiDAR survey'}],...
                'SelectionMode','single', 'InitialValue',1, 'PromptString', {'LiDAR survey'});
            if ind_lidar_option == 1 % airborne LiDAR
                %get_noaa_lidar %% TODO XXX
            elseif ind_lidar_option == 2 % local LiDAR survey
                disp('Find local LiDAR/SfM survey folder.')
                disp('For CPG LiDAR: CPG_data/LiDAR/20230220_NAD83_UTM11N_NAVD88_TorreyLot.las')
                disp('For CPG SfM: CPG_data/20220817_00581_00590_NoWaves_TorreyCobble_P4RTK_epoch2010_geoid12b.las')

                [pc] = load_pointcloud;
            end
            % XXX SOMETHING HERE XXX

        elseif ind_gcp_option == 2 % manual selection from LiDAR
            [ind_lidar_option,~] = listdlg('ListString',[{'Airborne LiDAR (TBD)'}, {'Local LiDAR/SfM survey'}],...
                'SelectionMode','single', 'InitialValue',1, 'PromptString', {'LiDAR/SfM survey'});
            if ind_lidar_option == 1 % airborne LiDAR
                %get_noaa_lidar %% TODO XXX
            elseif ind_lidar_option == 2 % local LiDAR survey
                disp('Find local LiDAR/SfM survey folder.')
                disp('For CPG LiDAR: CPG_data/LiDAR/20230220_NAD83_UTM11N_NAVD88_TorreyLot.las')
                disp('For CPG SfM: CPG_data/20220817_00581_00590_NoWaves_TorreyCobble_P4RTK_epoch2010_geoid12b.las')

                [pc] = load_pointcloud;
            end
            [world_gcp, image_gcp] = select_survey_gcp(pc, I, intrinsics_CIRN, extrinsicsInitialGuess); % includes select_image_gcp
            if ~isempty(pc.Color)
                gcp_method = 'manual_SfM';
            else
                gcp_method = 'manual_LiDAR';
            end

        elseif ind_gcp_option == 3 % manual selection from GoogleEarth
            gcp_method = 'manual_GoogleEarth';
            % XXX Discuss with Rafael and Erwin XXX

        elseif ind_gcp_option == 4 % manual selection of GCP targets (QCIT Toolbox)
            gcp_method = 'manual_targets';
            [image_gcp] = select_image_gcp(I);
            [world_gcp] = select_target_gcp;

        elseif ind_gcp_option == 5 % using metadata
           % [worldPose] = CIRN2MATLAB(extrinsics);
            % check azimuthal, pitch and roll from image - Brittany
            % method
            % XXX TBD XXX

        end

        % Getting CIRN extrinsics
        extrinsicsKnownsFlag= [0 0 0 0 0 0];  % [ x y z azimuth tilt swing]
        [extrinsics, extrinsicsError]= extrinsicsSolver(extrinsicsInitialGuess, extrinsicsKnownsFlag, intrinsics_CIRN, image_gcp, world_gcp);
        % TODO add in reprojectionError
        % TODO check that grid size all consistent

        % Getting MATLAB worldPose
        try % get worldPose
            worldPose = estworldpose(image_gcp,world_gcp, intrinsics);
        catch % get more points
            iGCP = image_gcp; clear image_gcp
            wGCP = world_gcp; clear world_gcp
            [ind_gcp_option2,~] = listdlg('ListString',[{'Select points from LiDAR/SfM'}, {'Select points from GoogleEarth (TBD)'}, {'Select GCP targets'}],...
                'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Requires more GCP points'});

            if ind_gcp_option2 == 1 % manual selection from LiDAR
                [ind_lidar_option,~] = listdlg('ListString',[{'Airborne LiDAR (TBD)'}, {'Local LiDAR/SfM survey'}],...
                    'SelectionMode','single', 'InitialValue',1, 'PromptString', {'LiDAR/SfM survey'});
                if ind_lidar_option == 1 % airborne LiDAR
                    %get_noaa_lidar %% TODO XXX
                elseif ind_lidar_option == 2 % local LiDAR survey
                    disp('Find local LiDAR/SfM survey folder.')
                    disp('For CPG LiDAR: CPG_data/LiDAR/20230220_NAD83_UTM11N_NAVD88_TorreyLot.las')
                    disp('For CPG SfM: CPG_data/20220817_00581_00590_NoWaves_TorreyCobble_P4RTK_epoch2010_geoid12b.las')

                    [pc] = load_pointcloud;
                end
                [world_gcp, image_gcp] = select_survey_gcp(pc, I, intrinsics_CIRN, extrinsicsInitialGuess); % includes select_image_gcp
                if ~isempty(pc.Color)
                    gcp_method = 'manual_SfM';
                else
                    gcp_method = 'manual_LiDAR';
                end % if ~isempty(pc.Color)

            elseif ind_gcp_option2 == 2 % manual selection from GoogleEarth
                gcp_method = 'manual_GoogleEarth';
                % Discuss with Rafael and Erwin

            elseif ind_gcp_option2 == 3 % manual selection of GCP targets (QCIT Toolbox)
                gcp_method = 'manual_targets';
                [image_gcp] = select_image_gcp(I);
                [world_gcp] = select_target_gcp;

            end % if ind_gcp_option2 == 1

            image_gcp = [iGCP; image_gcp];
            world_gcp = [wGCP; world_gcp];
            try
                worldPose = estworldpose(image_gcp,world_gcp, intrinsics);
            catch
                worldPose = rigidtform3d(eul2rotm([0 0 0]), [0 0 0]);
                if exist('user_email', 'var')
                    sendmail(user_email{2}, [oname '- World Pose not found'])
                end
            end % try

        end % try

        hGCP = figure(3);clf
        imshow(I)
        hold on
        scatter(image_gcp(:,1), image_gcp(:,2), 100, 'r', 'filled')
        for ii = 1:length(image_gcp)
            text(image_gcp(ii,1)+25, image_gcp(ii,2)-25, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end
        [UVd,flag] = xyz2DistUV(intrinsics_CIRN,extrinsics,world_gcp); UVd = reshape(UVd, [],2);
        scatter(UVd(:,1), UVd(:,2), 50, 'y', 'LineWidth', 3)
        % confirm that worldPose and camera extrinsics agree
        if max([extrinsics(1:3)-worldPose.Translation]) > 1 % if extrinsics location disagrees by more than 1m than need to reasses
            answer = questdlg('Problem with extrinsics or worldPose', 'Extrinsics Location Check', 'Yes', 'No', 'Yes');
            %%% XXX TBD XXX
        end


        save(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'extrinsicsInitialGuess', 'extrinsics','intrinsics_CIRN', 'gcp_method', 'image_gcp','world_gcp', 'worldPose', 'intrinsics')
        print(hGCP, '-dpng', fullfile(odir, 'Processed_data', 'gcp.png'))

        close all

        %% ========================extrinsicsMethod=====================================
        [ind_scp_method,tf] = listdlg('ListString',[{'Feature Matching'}, {'Using SCPs.'}],...
            'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Extrinsics Method'});
        save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable']),'ind_scp_method')

            %% ========================SCPs===============================================
            %  If using SCPs for tracking pose through time, extra step is required - define intensity threshold
            %  - Define search area radius - center of brightest (darkest) pixels in this region will be chosen as stability point from one frame to the next.
            %  - Define intensity threshold of brightest or darkest pixels in search area
            %  ============================================================================

        if ind_scp_method == 2 % Using SCPs (similar to CIRN QCIT)
            if strcmpi(gcp_method, 'manual_targets')
                % repeat for each extracted frame rate
                for hh = 1 : length(extract_Hz)
                    I=imread(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'));
                    [scp] = define_SCP(I, image_gcp, intrinsics_CIRN);
                    save(fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz(hh))) 'Hz']), 'scp')
                end
            else
                disp('Ground control targets are required to use stability control points.')
                % XXX TODO SOMETHING HERE XXX
            end % if strcmpi(gcp_method, 'manual_targets')
        end % if ind_scp_method == 4

        %% ========================productsCheck=======================================
        %                          CHECK PRODUCTS ON INITIAL IMAGE
        %                           - Load in all required data -
        %                             extrinsics inital guess, intrinsics, inital frame, input data, products
        %  =======================================================================5
        % =====

        load(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'extrinsics','intrinsics_CIRN')
        load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'Products')
        I=imread(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'));

        %% ========================grid================================================
        %                          GRID
        %                           - Projects grid onto inital frame
        %                           - If unhappy, can reinput grid data
        %  ============================================================================
        ids_grid = find(contains(extractfield(Products, 'type'), 'Grid'));
        for pp = ids_grid % repeat for all grids
            gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0
                plot_grid(Products(pp), I, intrinsics_CIRN, extrinsics)
                answer = questdlg('Happy with grid projection?', ...
                    'Grid projection',...
                    'Yes', 'No', 'Yes');

                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No'
                        disp('Please change grid.')
                        origin_grid = [Products(pp).lat Products(pp).lon, Products(pp).angle];
                        [Product1] = define_grid(origin_grid);

                        Products(pp) = Product1;

                end % check answer
            end % check gridCheckIndex
            print(gcf,'-dpng', fullfile(odir, 'Processed_data', [oname '_' char(string(pp)) '_Grid_Local.png' ]))
        end % for pp = 1:length(ids_grid)

        clearvars ids_grid info Product1 gridChangeIndex answer localIr Ir pp x2 y2 localExtrinsics ixlim iylim iX iY iz iZ X Y Z localX localY localZ

        %% ========================xTransects==========================================
        %                          xTransects
        %                           - Projects all xTransects onto inital frame
        %                           - If unhappy, can reinput transect data
        %  ============================================================================
        if ~isempty(find(contains(extractfield(Products, 'type'), 'xTransect')));
            gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0
                plot_xtransects(Products, I, intrinsics_CIRN, extrinsics)
                answer = questdlg('Happy with transect projection?', ...
                    'Transect Projection',...
                    'Yes', 'No', 'Yes');

                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No'
                        disp('Please change transects.')
                        origin_grid = [Products(ids_xtransect(1)).lat Products(ids_xtransect(1)).lon, Products(ids_xtransect(1)).angle];
                        Products(ids_xtransect) = [];
                        productCounter = length(Products);

                        [Product1] = define_xtransect(origin_grid);
                        Products(productCounter:productCounter+length(Product1))=Product1;

                end % check answer
            end % check gridCheckIndex
            print(gcf,'-dpng', fullfile(odir, 'Processed_data', [oname '_xTransects.png' ]))

            clearvars ids_xtransect pp jj x2 y2 ixlim iy X Y Z xyz UVd le answer gridChangeIndex
        end
        %% ========================yTransects==========================================
        %                         yTransects
        %                           - Projects all yTransects onto inital frame
        %                           - If unhappy, can reinput transect data
        %  ============================================================================
        if ~isempty(find(contains(extractfield(Products, 'type'), 'yTransect')));
            gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0

                plot_ytransects(Products, I, intrinsics_CIRN, extrinsics)
                answer = questdlg('Happy with rough transect numbers?', ...
                    'Transect Numbers',...
                    'Yes', 'No', 'Yes');
                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No'
                        disp('Please change transects.')
                        origin_grid = [Products(ids_ytransect(1)).lat Products(ids_ytransect(1)).lon, Products(ids_ytransect(1)).angle];
                        Products(ids_ytransect) = [];
                        productCounter = length(Products);

                        [Product1] = define_ytransect(origin_grid);
                        Products(productCounter:productCounter+length(Product1))=Product1;


                end % switch answer
            end % check gridCheckIndex
            print(gcf,'-dpng',fullfile(odir, 'Processed_data', [oname '_yTransects.png' ]))

            clearvars pp jj x2 y2 iylim ix X Y Z xyz UVd le answer gridChangeIndex
        end
        %% ========================email===============================================
        %                         SEND EMAIL WITH INPUT DATA
        %                           - Origin of Coordinate System
        %                           - Initial and corrected Camera Position
        %                           - worldPose and image stabilization method (2D, 3D, SCP)
        %                           - Data extraction frame rates
        %                           - Products
        %  ============================================================================
        clear grid_text grid_plot
        load(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']))
        grid_text{1} = sprintf('Lat / Long = %.2f / %.2f, Angle = %.2f deg', Products(1).lat, Products(1).lon, Products(1).angle);
        grid_text{2} = sprintf('Initial Extrinsics Guess: %.2f, %.2f, %.2f, %.2f, %.2f, %.2f', extrinsicsInitialGuess);
        grid_text{3} = sprintf('Corrected Extrinsics Guess: %.2f, %.2f, %.2f, %.2f, %.2f, %.2f with %s method', extrinsics, gcp_method);
        grid_text{4} = sprintf('World Pose: %.2f, %.2f, %.2f', worldPose.Translation);
        if ind_scp_method == 1
            grid_text{5} = sprintf('Using Feature Detection.');
            % if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5)
            %     grid_text{5} = sprintf('Coarse Pose Estimation: Small Azimuthal Change (2D rotation)');
            % else
            %     if contains(R.rot_answer, '2D')
            %         grid_text{5} = sprintf('Coarse Pose Estimation: Large Azimuthal Change - do 2D transformation and stop when rotation angle > 5deg.');
            %     elseif contains(R.rot_answer, '3D')
            %         grid_text{5} = sprintf('Coarse Pose Estimation: Large Azimuthal Change - do 3D transformation - noisier');
            %     end % if contains(R.rot_answer, '2D')
            % end % if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5)
        elseif ind_scp_method == 2
            grid_text{5} = sprintf('Using SCPs.');
        end % if ind_scp_method == 1

        grid_text{6} = sprintf('Extract data at %i Hz. ', extract_Hz);
        grid_text{7} = sprintf('Products to produce:');

        grid_plot{1} = fullfile(odir ,'Processed_data', 'undistortImage.png');
        grid_plot{2} = fullfile(odir ,'Processed_data', 'gcp.png');
        ids_grid = find(contains(extractfield(Products, 'type'), 'Grid'));
        ids_xtransect = find(contains(extractfield(Products, 'type'), 'xTransect'));
        ids_ytransect = find(contains(extractfield(Products, 'type'), 'yTransect'));

        for pp = ids_grid
            grid_text{length(grid_text)+1} = sprintf('Type = %s, frameRate = %i Hz, xlim = [%i %i], ylim = [%i %i], (dx,dy) = [%.1f %.1f] m', Products(pp).type, Products(pp).frameRate, Products(pp).xlim(1), Products(pp).xlim(2), Products(pp).ylim(1), Products(pp).ylim(2), Products(pp).dx, Products(pp).dy);
            grid_plot{length(grid_plot)+1} =fullfile(odir ,'Processed_data', [oname '_' char(string(pp)) '_Grid_Local.png' ]);
        end
        for pp = ids_xtransect
            grid_text{length(grid_text)+1} = sprintf('Type = %s, frameRate = %i Hz, xlim = [%i %i], y = %.1f m, dx = %.1f m', Products(pp).type, Products(pp).frameRate, Products(pp).xlim(1), Products(pp).xlim(2), Products(pp).y, Products(pp).dx);
        end
        for pp = ids_ytransect
            grid_text{length(grid_text)+1} = sprintf('Type = %s, frameRate = %i Hz, x = %.1f m, ylim = [%i %i], dy = %.1f m', Products(pp).type, Products(pp).frameRate, Products(pp).x, Products(pp).ylim(1), Products(pp).ylim(2), Products(pp).dy);
        end
        if ~isempty(ids_xtransect)
            grid_plot{length(grid_plot)+1} =fullfile(odir ,'Processed_data',  [oname '_xTransects.png' ]);
        end
        if ~isempty(ids_ytransect)
            grid_plot{length(grid_plot)+1} = fullfile(odir ,'Processed_data', [oname '_yTransects.png' ]);
        end
        if exist('user_email', 'var') && ~isempty(user_email)
            sendmail(user_email{2}, [oname '- Input Data'], grid_text, grid_plot)
        end

        close all
    end % for ff = 1:length(flights)
end % for dd = 1:length(day_files)
clearvars -except *_dir user_email day_files
cd(global_dir)
close all
