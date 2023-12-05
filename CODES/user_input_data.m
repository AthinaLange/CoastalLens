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
            sendmail(user_email{2}, 'UAV Toolbox test email', [user_email{1} ' is processing UAV data from ' data_files.name '.'])
            
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
%                                   - with Feature Matching - do coarse pose estimation (every 30sec 2D image warping)
%                               - check products
%  =====================================================================
for dd = 1 : length(data_files)

    clearvars -except dd *_dir user_email data_files
    cd([data_files(dd).folder '/' data_files(dd).name])
           %% ==========================inputData==========================================
            %                                                    Load in input_data if already specified       
            %  =====================================================================
      
        % Check if user already has input file with all general drone / products information
        % 
        disp('For CPG: ''input_data.mat'' in day files.')
        input_answer = questdlg('Do you have a .mat input data file?','Input Data File', 'Yes', 'No', 'No');
        switch input_answer
            case 'Yes'
                disp('Load in input file.')
                disp('For CPG: ''input_data.mat'' in day files.')
                [temp_file, temp_file_path] = uigetfile(global_dir, 'Input File');
                load(fullfile(temp_file_path, temp_file)); clear temp_file*
        end

           %% ==========================DroneType==========================================
           %                                                    Choose drone system        
           %  =====================================================================
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
           %  =====================================================================
           if ~exist('tz', 'var') || ~ischar(tz)
                cont_areas = [{'Africa'}, {'America'}, {'Antarctica'}, {'Arctic'}, {'Asia'}, {'Atlantic'}, {'Australia'}, {'Europe'}, {'Indian'}, {'Pacific'}, {'All'}];
                [ind_area,tf] = listdlg('ListString', cont_areas, 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Which geographic region are you in?'});
                
                geo_areas = timezones(char(cont_areas(ind_area)));
                [ind_area,tf] = listdlg('ListString', geo_areas.Name, 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Which geographic region are you in?'});
                tz = char(geo_areas.Name(ind_area));
           end
           %% ==========================intrinsics==========================================
            %                                   Choose intrinsics file for each day of flight         
            %  =====================================================================
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
           %% ==========================product==========================================
            %                          DEFINE PRODUCT TYPE       
            %                           - Do you already have a product file - as made from user_input_products.m
            %                               - If so, can load that in
            %                           - Define origin of grid and products to be made
            %  =====================================================================
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
                            user_input_products
                        end
                    case 'No'
                        user_input_products
                end
                clear answer
            end
           %% ==========================extractionRate==========================================
            %                          EXTRACTION FRAME RATES
            %                           - Find frame rates of products
            %                           - Find minimum sets of frame rates to satisfy product frame rates, 
            %                             i.e. 2Hz data can be pulled from 10Hz images
            %  =====================================================================
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
           %% ==========================saveDayData===========================================
            %                          SAVE DAY RELEVANT DATA       
            %                           - Save camera intrinsics, extraction frame rates, products, flights for specific day, drone type and timezone
            %  =============================================================================
            flights = dir(fullfile(data_files(dd).folder, data_files(dd).name)); flights([flights.isdir]==0)=[]; flights(contains({flights.name}, '.'))=[]; flights(contains({flights.name}, 'GCP'))=[];
           switch input_answer
               case 'No'
                    save(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'),...
                        'cameraParams*', 'extract_Hz', 'Products', 'flights', 'drone_type', 'tz')
           end

    %% ====================================================================
    %                          PROCESS EACH FLIGHT
    %  =====================================================================
    for ff = 1:length(flights)
        clearvars -except dd ff *_dir user_email data_files
        load(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'))
        
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [data_files(dd).name '_' flights(ff).name];
        cd(odir) 
        if ~exist(fullfile(odir, 'Processed_data'), 'dir')
            mkdir 'Processed_data'
        end
   
        %% ========================metadata============================================
        %                          INITIAL DRONE COORDINATES FROM METADATA        
        %                           - Use exiftool to pull metadata from images and video
        %                               - currently set for DJI name
        %                               - mov_id indicates which movies to use in image extraction
        %                               - get inital camera position and pose from metadata
        %  =====================================================================
       if contains(drone_type, 'DJI')
           drone_file_name = 'DJI';
       else
            temp_name = string(inputdlg({'What is the file prefix?'}));
            drone_file_name = temp_name(1);
       end

       system(sprintf('/usr/local/bin/exiftool -filename -CreateDate -Duration -CameraPitch -CameraYaw -CameraRoll -AbsoluteAltitude -RelativeAltitude -GPSLatitude -GPSLongitude -csv -c "%%.20f" %s/%s_0* > %s', odir, drone_file_name, fullfile(odir, 'Processed_data', [oname '.csv'])));
        
        C = readtable(fullfile(odir, 'Processed_data', [oname '.csv']));
      
        format long
        % get indices of images and videos to extract from
        form = char(C.FileName);
        form = string(form(:,end-2:end));
        mov_id = find(form == 'MOV' | form == 'MP4');
        jpg_id = find(form == 'JPG');
        
        % remove any weird videos
        i_temp = find(isnan(C.Duration(mov_id))); mov_id(i_temp)=[];
    
        % if image taken at beginning & end of flight - use beginning image
        if length(jpg_id) > 1; jpg_id = jpg_id(1); end
        % if no image taken, use mov_id
        if isempty(jpg_id); jpg_id = mov_id(1); end

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
        
        save(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'extrinsicsInitialGuess', 'UTMNorthing', 'UTMEasting', 'zgeoid_offset', 'jpg_id', 'mov_id', 'lat', 'long', 'C')
        
        clearvars form i_temp  lat long zgeoid_offset UTMNorthing UTMEasting UTMZone
        %% ========================initialFrame============================================
        %                          EXTRACT INITIAL FRAME       
        %                           - Use ffmpeg tool to extract first frame to be used for distortion and product location check
        %  =====================================================================
        if ~exist(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'), 'file')    
            system(['ffmpeg -ss 00:00:00 -i ' char(string(C.FileName(mov_id(1)))) ' -frames:v 1 -loglevel quiet -stats -qscale:v 2 Processed_data/Initial_frame.jpg']);
        end

        %% ========================distortion============================================
        %                          CONFIRM DISTORTION       
        %                           - If cameraParameters includes both a _distorted and _undistorted version
        %                               - show initial frame, initial frame corrected with _distorted and with _undistorted 
        %                                 and confirm with user which distortion correction should be used.
        %                           - If cameraParameters includes only one calibration
        %                               - show initial frame and initial frame corrected with calibration 
        %                                 and confirm with user that you are happy with calibration
        %                           - Save intrinsics fille in suitable format
        %  =====================================================================
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
        intrinsics(1) = cameraParams.ImageSize(2);            % Number of pixel columns
        intrinsics(2) = cameraParams.ImageSize(1);            % Number of pixel rows
        intrinsics(3) = cameraParams.PrincipalPoint(1);         % U component of principal point  
        intrinsics(4) = cameraParams.PrincipalPoint(2);          % V component of principal point
        intrinsics(5) = cameraParams.FocalLength(1);         % U components of focal lengths (in pixels)
        intrinsics(6) = cameraParams.FocalLength(2);         % V components of focal lengths (in pixels)
        intrinsics(7) = cameraParams.RadialDistortion(1);         % Radial distortion coefficient
        intrinsics(8) = cameraParams.RadialDistortion(2);         % Radial distortion coefficient
        if length(cameraParams.RadialDistortion) == 3
            intrinsics(9) = cameraParams.RadialDistortion(3);         % Radial distortion coefficient
        else
            intrinsics(9) = 0;         % Radial distortion coefficient
        end
        intrinsics(10) = cameraParams.TangentialDistortion(1);        % Tangential distortion coefficients
        intrinsics(11) = cameraParams.TangentialDistortion(2);        % Tangential distortion coefficients
        
        if (exist('cameraParams_distorted', 'var') & exist('cameraParams_undistorted', 'var') ) && ind_distortion == 2 
            intrinsics(7:11) = 0; % no distortion (if distortion correction on)
        end

        intrinsics_CIRN = intrinsics;
        intrinsics = cameraParams.Intrinsics; 
        save(fullfile(odir, 'Processed_data', [oname '_IO']), 'intrinsics_CIRN', 'intrinsics', 'cameraParams', 'extrinsicsInitialGuess')
        clearvars I J1 J2 tf ind_distortion hFig cameraParams_*
        close all
        %% ========================GCPs============================================
        %                          GET GCPs HERE (TODO)       
        %                           - Option 1: Fully Automated from LiDAR points
        %        DONE                   - Option 2: Manual from hand selection from LiDAR or SfM (airborne or local)
        %                           - Option 3: Manual from hand selection from GoogleEarth
        %        DONE                   - Option 4: Manual from GCP targets
        %                           - Option 5: Use camera metadata
        %  =====================================================================
        % whichever method generates image_gcp (N x 2) and world_gcp (N x 3)

         [ind_gcp_option,tf] = listdlg('ListString',[{'Automated from Airborne LiDAR'}, {'Select points from LiDAR/SfM'}, {'Select points from GoogleEarth'}, {'Select GCP targets'}, {'Use Metadata'}],...
                                                     'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Initial GCP Method'});
          
         if ind_gcp_option == 1 % automated from LiDAR
              gcp_method = 'auto_LiDAR';
                [ind_lidar_option,~] = listdlg('ListString',[{'Airborne LiDAR'}, {'Local LiDAR survey'}],...
                                                     'SelectionMode','single', 'InitialValue',1, 'PromptString', {'LiDAR survey'});
                if ind_lidar_option == 1 % airborne LiDAR
                        get_noaa_lidar %% TODO XXX
                elseif ind_lidar_option == 2 % local LiDAR survey
                        get_local_survey
                end
                % XXX SOMETHING HERE XXX

          elseif ind_gcp_option == 2 % manual selection from LiDAR
                [ind_lidar_option,~] = listdlg('ListString',[{'Airborne LiDAR'}, {'Local LiDAR/SfM survey'}],...
                                                     'SelectionMode','single', 'InitialValue',1, 'PromptString', {'LiDAR/SfM survey'});
                if ind_lidar_option == 1 % airborne LiDAR
                        get_noaa_lidar %% TODO XXX
                elseif ind_lidar_option == 2 % local LiDAR survey
                        get_local_survey
                end
                select_survey_gcp % includes select_image_gcp
                world_gcp = survey_gcp;
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
               select_image_gcp
               select_target_gcp
               world_gcp = target_gcp;

          elseif ind_gcp_option == 5 % using metadata
              [worldPose] = CIRN2MATLAB(extrinsics);
              % check azimuthal, pitch and roll from image - Brittany
              % method
              % XXX TBD XXX

          end

        % Getting CIRN extrinsics
        extrinsicsKnownsFlag= [0 0 0 0 0 0];  % [ x y z azimuth tilt swing]
        [extrinsics extrinsicsError]= extrinsicsSolver(extrinsicsInitialGuess, extrinsicsKnownsFlag, intrinsics_CIRN, image_gcp, world_gcp);
        % TODO add in reprojectionError
        % TODO check that grid size all consistent
        
        % Getting MATLAB worldPose
        try % get worldPose
            worldPose = estworldpose(image_gcp,world_gcp, intrinsics);
        catch % get more points
            iGCP = image_gcp; clear image_gcp
            wGCP = world_gcp; clear world_gcp
            [ind_gcp_option2,tf] = listdlg('ListString',[{'Select points from LiDAR/SfM'}, {'Select points from GoogleEarth'}, {'Select GCP targets'}],...
                                                     'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Requires more GCP points'});
         
            if ind_gcp_option2 == 1 % manual selection from LiDAR
                [ind_lidar_option,~] = listdlg('ListString',[{'Airborne LiDAR'}, {'Local LiDAR/SfM survey'}],...
                                                     'SelectionMode','single', 'InitialValue',1, 'PromptString', {'LiDAR/SfM survey'});
                if ind_lidar_option == 1 % airborne LiDAR
                        get_noaa_lidar %% TODO XXX
                elseif ind_lidar_option == 2 % local LiDAR survey
                        get_local_survey
                end
                select_survey_gcp % includes select_image_gcp
                world_gcp = survey_gcp;
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
                   select_image_gcp
                   select_target_gcp
                   world_gcp = target_gcp;
    
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
            answer = questdlg('Problem with extrinsics or worldPose', 'Extrinsics Location Check', 'Yes', 'No', 'Yes')
            %%% XXX TBD XXX
        end


        save(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'extrinsicsInitialGuess', 'extrinsics','intrinsics_CIRN', 'gcp_method', 'image_gcp','world_gcp', 'worldPose', 'intrinsics')
        print(hGCP, '-dpng', fullfile(odir, 'Processed_data', 'gcp.png'))

        close all
 
        %% ========================extrinsicsMethod=======================================
         [ind_scp_method,tf] = listdlg('ListString',[{'Feature Matching'}, {'Using SCPs.'}],...
                                                     'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Extrinsics Method'});
         save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable']),'ind_scp_method')
        
        %% ========================coarsePoseEstimation======================================
        %                          - Extract images at every 30sec for a coarse pose estimation
        %                          - Assuming little azimuthal rotation - get 2D rotation
        %                          - If rotation angle > 5deg, prompt user if they want 3D transformation or 2D rotation
        %                               - 3D transformation much noisier than 2D, but can do adjustment for full length of video
        %  =================================================================================
     
        if ind_scp_method == 1
        mkdir('temp_images')
        imageDirectory = 'temp_images';
        load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'jpg_id', 'mov_id', 'C')
        jj=0;
        % repeat for each video
        for ii = 1 : length(mov_id)
            v = VideoReader(string(C.FileName(mov_id(ii))));
            for nn = 1:30*round(v.FrameRate):v.NumFrames
                jj=jj+1;
                if jj < 10
                    id=sprintf('0000%i', jj);
                elseif jj < 100
                    id=sprintf('000%i', jj);
                elseif jj < 1000
                    id=sprintf('00%i', jj);
                elseif jj < 10000
                    id=sprintf('0%i', jj);
                else
                    id=sprintf('%i', jj);
                end
                imwrite(read(v,nn), [imageDirectory '/Frame_' id '.jpg'])
            end
        end
        
        images = imageDatastore(imageDirectory);
        I = readimage(images,1);
        figure(1);clf
        image(I)
        xticks([])
        yticks([size(I,1)*[0.05:0.05:1]])
        yticklabels({'5%', '10%', '15%', '20%', '25%', '30%', '35%', '40%', '45%', '50%', '55%', '60%', '65%', '70%', '75%', '80%', '85%', '90%', '95%', '100%'})
        yline(round(size(I,1)*(3/4)), 'LineWidth', 3, 'Color', 'r')
        yline(round(size(I,1)*(1/2)), 'LineWidth', 3, 'Color', 'r')
        title('Example Cutoffs')
    
        cutoff_fraction = string(inputdlg({'Bottom fraction of image to use for feature matching (e.g., 3/4 or 0.75 or 75)'}));
        if contains(cutoff_fraction, '.')
            cutoff_fraction = str2double(cutoff_fraction);
        elseif contains(cutoff_fraction, '/')
            ab=sscanf(cutoff_fraction,'%d/%d'); cutoff_fraction = ab(1)/ab(2);
        else
            cutoff_fraction = str2double(cutoff_fraction); cutoff_fraction = cutoff_fraction/100;
        end
        cutoff = round(size(I,1)*(cutoff_fraction));
        [R, rot_answer] = get_coarse_pose_estimation(images, intrinsics, cutoff);
        R.rot_answer = rot_answer;
        R.cutoff = cutoff;
        rmdir(imageDirectory, 's')

        save(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'R', '-append')
        close all
        
       %% ========================SCPs============================================
        %  If using SCPs for tracking pose through time, extra step is required - define intensity threshold
        %  - Define search area radius - center of brightest (darkest) pixels in this region will be chosen as stability point from one frame to the next.
        %  - Define intensity threshold of brightest or darkest pixels in search area
        
    elseif ind_scp_method == 2 % Using SCPs (similar to CIRN QCIT)
            if strcmpi(gcp_method, 'manual_targets')
                % repeat for each extracted frame rate
                for hh = 1 : length(extract_Hz)
            
                    I=imread(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'));
                    hFig = figure(1);clf
                    imshow(I)
                    hold on
                    scatter(image_gcp(:,1), image_gcp(:,2), 50, 'y', 'LineWidth', 3)
                    for ii = 1:length(image_gcp)
                        text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
                    end
                    answer_z = questdlg('Are elevation values in GCP coordinates file?', ...
                                                      'SCP Elevation',...
                                                      'Yes', 'No', 'Yes');
                    switch answer_z
                            case 'Yes'
                                disp('Load in target GCP coordinates file.')
                                disp('For CPG: Should be under the individual day. gps_northings.txt')
                                 [temp_file, temp_file_path] = uigetfile({'*.txt'}, 'GCP Targets');
                                 load(fullfile(temp_file_path, temp_file)); clear temp_file*
                                 for gg = 1:length(gps_northings)
                                    gcp_options(gg,:) = sprintf('%i - %.2fm', gg, gps_northings(gg,4));
                                 end
                      end
                    
                    for gg = 1:length(image_gcp)
                        %% ========================radius============================================
                            %                           - Determine search area around bright or dark target. 
                            %  =====================================================================
                        hFig   
                        scp(gg).UVdo = image_gcp(gg,:);
                        scp(gg).num = gg;
                    
                        xlim([image_gcp(gg,1)-intrinsics_CIRN(1)/10 image_gcp(gg,1)+intrinsics_CIRN(1)/10])
                        ylim([image_gcp(gg,2)-intrinsics_CIRN(2)/10 image_gcp(gg,2)+intrinsics_CIRN(2)/10])
                    
                        prev_radius = 50;
                        h=rectangle('position',[image_gcp(gg,1)-prev_radius,image_gcp(gg,2)-prev_radius,2*prev_radius,2*prev_radius],'EdgeColor','r','linewidth',1);
                        
                        while true
                            new_radius = double(string(inputdlg({'Area of Interest Size'}, 'Click Enter with previous radius to finish.',1, {num2str(prev_radius)})));
                            if new_radius ~= prev_radius
                                delete(h)
                                h=rectangle('position',[image_gcp(gg,1)-new_radius,image_gcp(gg,2)-new_radius,2*new_radius,2*new_radius],'EdgeColor','r','linewidth',1);
                                prev_radius = new_radius;
                            else
                                break;
                            end % if new_radius ~= prev_radius
                        end % while true
                        scp(gg).R = prev_radius;
                    
                        %% ========================threshold============================================
                            %                           - Determine threshold value for bright (dark) point - used for tracking through images
                            %  =====================================================================
                         
                        I_gcp = I(round(scp(gg).UVdo(2)-scp(gg).R):round(scp(gg).UVdo(2)+scp(gg).R), round(scp(gg).UVdo(1)-scp(gg).R):round(scp(gg).UVdo(1)+scp(gg).R), :);
                        hIN = figure(2);clf
                        hIN.Position(3)=3*hIN.Position(4);
                        subplot(121)
                        imshow(rgb2gray(I_gcp))
                        colormap jet
                        hold on
                        cb = colorbar; caxis([0 256]);
                        answer = questdlg('Bright or dark threshold', ...
                                         'Threshold direction',...
                                         'bright', 'dark', 'bright');
                        scp(gg).brightFlag = answer;    
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
                        scp(gg).T = prev_threshold;
                        close(hIN)
                        %% ========================elevation============================================
                            %                           - Pull corresponding elevation value
                            %  =====================================================================
                        switch answer_z
                            case 'Yes'
                                [ind_gcp,tf] = listdlg('ListString', gcp_options, 'SelectionMode','single', 'InitialValue',[gg], 'PromptString', {'What ground control points' 'did you use?'});
                                scp(gg).z = gps_northings(ind_gcp, 4);
                            case 'No'
                                scp(gg).z = double(string(inputdlg({'Elevation'})));
                        end
            
                    end % for gg = 1:length(image_gcp)
                    save(fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz(hh))) 'Hz']), 'scp')
                end
            else
                disp('Ground control targets are required to use stability control points.')
                % XXX TODO SOMETHING HERE XXX
            end % if strcmpi(gcp_method, 'manual_targets')
end % if ind_scp_method == 4

        %% ========================productsCheck============================================
        %                          CHECK PRODUCTS ON INITIAL IMAGE       
        %                           - Load in all required data -
        %                             extrinsics inital guess, intrinsics, inital frame, input data, products
        %  =====================================================================

        load(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'extrinsics','intrinsics_CIRN')
        load(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'), 'Products')
        I=imread(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'));
    
        ids_grid = find(contains(extractfield(Products, 'type'), 'Grid'));
        ids_xtransect = find(contains(extractfield(Products, 'type'), 'xTransect'));
        ids_ytransect = find(contains(extractfield(Products, 'type'), 'yTransect'));

        %% ========================grid============================================
        %                          GRID       
        %                           - Projects grid onto inital frame
        %                           - If unhappy, can reinput grid data
        %  =====================================================================
        ids_grid = find(contains(extractfield(Products, 'type'), 'Grid'));
        for pp = ids_grid % repeat for all grids
        gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0
                [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
                localExtrinsics = localTransformExtrinsics([x2 y2], Products(pp).angle-270, 1, extrinsics);
                
                if Products(pp).xlim(1) < 0; Products(pp).xlim(1) = -Products(pp).xlim(1); end
                ixlim = x2 - Products(pp).xlim;
                
                if Products(pp).ylim(1) > 0; Products(pp).ylim(1) = -Products(pp).ylim(1); end
                if Products(pp).ylim(2) < 0; Products(pp).ylim(2) = -Products(pp).ylim(2); end
                iylim = y2 + Products(pp).ylim;
        
                [iX, iY]=meshgrid(ixlim(1):Products(pp).dx:ixlim(2),iylim(1):Products(pp).dy:iylim(2));
                
                % DEM stuff
                if isempty(Products(pp).z); iz=0; else; iz = Products(pp).z; end
                iZ=iX*0+iz;
                
                X=iX; Y=iY; Z=iZ; 
                [localX, localY]=localTransformEquiGrid([x2 y2], Products(pp).angle-270,1,iX,iY); 
                localZ=localX.*0+iz; 
                
                [Ir]= imageRectifier(I,intrinsics_CIRN,extrinsics,X,Y,Z,1);
                subplot(2,2,[2 4])
                title('World Coordinates')
                
                [localIr]= imageRectifier(I,intrinsics_CIRN,localExtrinsics,localX,localY,localZ,1);
                
                subplot(2,2,[2 4])
                title('Local Coordinates')
                
                answer = questdlg('Happy with grid projection?', ...
                     'Grid projection',...
                     'Yes', 'No', 'Yes');
        
                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No'
                       disp('Please change grid.')
                       info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                                     'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
                                     'dx', 'dy', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'})));
                        
                       info = abs(info); % making everything +meters from origin
                    
                        % check that there's a value in all the required fields
                        if find(isnan(info)) ~= 8
                            disp('Please fill out all boxes (except z elevation if necessary)')
                            info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                                         'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
                                         'dx', 'dy', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'})));
                            info = abs(info); % making everything +meters from origin
                        end % if find(isnan(info)) ~= 8
                        
                        if info(1) > 30
                            disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
                            info(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
                        end
                        Products(pp).frameRate = info(1);
            
                        Products(pp).xlim = [info(2) -info(3)]; % offshore limit is negative meters
                        if Products(pp).angle < 180 % East Coast
                            Products(pp).ylim = [-info(5) info(4)]; % -north +south
                        elseif Products(pp).angle > 180 % West Coast
                            Products(pp).ylim = [-info(4) info(5)]; % -south +north
                        end % if Products(pp).angle < 180
                        Products(pp).dx = info(6);
                        Products(pp).dy = info(7);
                        if ~isnan(info(8))
                            Products(pp).z = info(8);
                        else
                            % PULL IN DEM
                        end % if ~isnan(info(8))
                end % check answer
            end % check gridCheckIndex
            print(gcf,'-dpng', fullfile(odir, 'Processed_data', [oname '_' char(string(pp)) '_Grid_Local.png' ]))
        end % for pp = 1:length(ids_grid)

        clearvars ids_grid info gridChangeIndex answer localIr Ir pp x2 y2 localExtrinsics ixlim iylim iX iY iz iZ X Y Z localX localY localZ
        
        %% ========================xTransects============================================
        %                          xTransects       
        %                           - Projects all xTransects onto inital frame
        %                           - If unhappy, can reinput grid data
        %  =====================================================================
        ids_xtransect = find(contains(extractfield(Products, 'type'), 'xTransect'));
        
        if ~isempty(ids_xtransect)
            
            gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0
                figure(5);clf
                hold on
                imshow(I)
                hold on
                title('Timestack')
                jj=0;
                for pp = ids_xtransect % repeat for all xtransects
                    jj=jj+1;
            
                    [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
                    localExtrinsics = localTransformExtrinsics([x2 y2], Products(pp).angle-270, 1, extrinsics(1,:));
                    
                    if Products(pp).xlim(1) < 0; Products(pp).xlim(1) = -Products(pp).xlim(1); end
                    if Products(pp).xlim(2) > 0; Products(pp).xlim(2) = -Products(pp).xlim(2); end
                    ixlim = x2 - Products(pp).xlim;
                    iX = [ixlim(1):Products(pp).dx:ixlim(2)];
                    
                    iY = y2 + Products(pp).y;
            
                    % DEM stuff
                    if isempty(Products(pp).z); iz=0; else; iz = Products(pp).z; end
                    iZ=iX*0+iz;
                    
                    X=iX; Y=iY; Z=iZ; 
                    [localX, localY]=localTransformPoints([x2 y2], Products(pp).angle-270,1,iX,iY); 
                    localZ=localX.*0+iz; 
                    xyz = cat(2,localX(:), localY(:), localZ(:));

                    [UVd] = xyz2DistUV(intrinsics_CIRN, localExtrinsics,xyz);
                    
                    UVd = reshape(UVd,[],2);
                    plot(UVd(:,1),UVd(:,2),'*')
                    xlim([0 intrinsics_CIRN(1)])
                    ylim([0  intrinsics_CIRN(2)])
                
                    le{jj}= [Products(pp).type ' - y = ' char(string(Products(pp).y)) 'm'];
                   
                end % for pp = 1:length(ids_xtransect)
                legend(le)

             answer = questdlg('Happy with transect projection?', ...
                     'Transect Projection',...
                     'Yes', 'No', 'Yes');
        
                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No'
                       disp('Please change transects.')
                       Products(ids_xtransect) = [];
                       productCounter = length(Products);

                       info = inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                         'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]',...
                         'dx', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type);
          
                     % check that there's a value in all the required fields
                    if ~isempty(find(isnan(double(string(info([1 2 3 5]))))))
                        disp('Please fill out all boxes (except z elevation if necessary)')
                        info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin)', ...
                                     'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]',...
                                     'dx', 'z elevation (tide level in relevant datum - leave blank if you want to use a DEM)'}, Product1.type)));
                    end % if ~isempty(find(isnan(double(string(info([1 2 3 5]))))))
                
                    info_num = abs(double(string(info([1 2 3 5 6])))); % making everything +meters from origin
            
                    if info_num(1) > 30
                        disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
                        info_num(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
                    end
                    Product1.frameRate = info_num(1);
                    Product1.xlim = [-info_num(2) info_num(3)]; % offshore limit is negative meters
                    Product1.dx = info_num(4);
                
                    yy = string(info(4));
                    if contains(yy, ',')
                        yy = double(split(yy, ','));
                    elseif contains(yy, ':')
                        eval(['yy= ' char(yy)]);
                    else
                        disp('Please input in the correct format (comma-separated list or [ylim1:dy:ylim2])')
                        yy = string(inputdlg({'Alongshore location of transects (m from Origin) - e.g. -100, 0, 100 OR [-100:100:100]'}));
                    end %  if contains(yy, ',')
                
                    if ~isnan(info_num(5))
                        Product1.z = info_num(5);
                    else
                        % PULL IN DEM
                    end  

                    for ii = 1:length(yy)
                        Product1.y = yy(ii);
                        Products(productCounter + ii) = Product1;
                    end

                end % check answer
            end % check gridCheckIndex
            print(gcf,'-dpng', fullfile(odir, 'Processed_data', [oname '_xTransects.png' ]))
            
        end % if ~isempty(ids_xtransect)
  
         clearvars ids_xtransect pp jj x2 y2 ixlim iy X Y Z xyz UVd le answer gridChangeIndex
       
        %% ========================yTransects============================================
        %                         yTransects       
        %                           - Projects all yTransects onto inital frame
        %                           - If unhappy, can reinput grid data
        %  =====================================================================
        if ~isempty(ids_ytransect)
            figure
            hold on
            imshow(I)
            hold on
            title('yTransect')
            jj=0
            for pp = ids_ytransect
                jj=jj+1;
                [y2,x2, ~] = ll_to_utm(Products(pp).lat, Products(pp).lon);
                localExtrinsics = localTransformExtrinsics([x2 y2], Products(pp).angle-270, 1, extrinsics);
                
                if Products(pp).ylim(1) > 0; Products(pp).ylim(1) = -Products(pp).ylim(1); end
                if Products(pp).ylim(2) < 0; Products(pp).ylim(2) = -Products(pp).ylim(2); end
                iylim = y2 + Products(pp).ylim;
            
                ix = x2 + Products(pp).x;
            
                Y = [iylim(1):Products(pp).dy:iylim(2)]';
                X = Y.*0+ix;
                if isempty(Products(pp).z); iz=0; else; iz = Products(pp).z; end
                Z = Y.*0 + iz;
                [ Xout Yout]= localTransformPoints([x2 y2], Products(pp).angle-270,1,X,Y);
                xyz = cat(2,Xout(:), Yout(:), Z(:));
            
                [UVd] = xyz2DistUV(intrinsics_CIRN, localExtrinsics,xyz);
                    
                UVd = reshape(UVd,[],2);
                plot(UVd(:,1),UVd(:,2),'*')
                xlim([0 intrinsics_CIRN(1)])
                ylim([0  intrinsics_CIRN(2)])
            
                le{jj}= [Products(pp).type ' - x = ' char(string(Products(pp).x)) 'm'];
               
            end % for pp = 1:length(ids_xtransect)
            legend(le)
            answer = questdlg('Happy with rough transect numbers?', ...
                         'Transect Numbers',...
                         'Yes', 'No', 'Yes');
            switch answer
                case 'Yes'
                    gridChangeIndex = 1;
                case 'No'
                   disp('Please change new transect numbers.')
                   define_product_type
            end % switch answer
            print(gcf,'-dpng',fullfile(odir, 'Processed_data', [oname '_yTransects.png' ]))
        end % if ~isempty(ids_ytransect)
        
        clearvars pp jj x2 y2 iylim ix X Y Z xyz UVd le answer gridChangeIndex
       
        %% ========================email============================================
        %                         SEND EMAIL WITH INPUT DATA  
        %                           - Origin of Coordinate System
        %                           - Initial and corrected Camera Position
        %                           - worldPose and image stabilization method (2D, 3D, SCP)
        %                           - Data extraction frame rates
        %                           - Products
        %  =====================================================================
        clear grid_text grid_plot
        load(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']))
        grid_text{1} = sprintf('Lat / Long = %.2f / %.2f, Angle = %.2f deg', Products(1).lat, Products(1).lon, Products(1).angle);
        grid_text{2} = sprintf('Initial Extrinsics Guess: %.2f, %.2f, %.2f, %.2f, %.2f, %.2f', extrinsicsInitialGuess)
        grid_text{3} = sprintf('Corrected Extrinsics Guess: %.2f, %.2f, %.2f, %.2f, %.2f, %.2f with %s method', extrinsics, gcp_method)
        grid_text{4} = sprintf('World Pose: %.2f, %.2f, %.2f', worldPose.Translation);
        if ind_scp_method == 1
            if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5)
                grid_text{5} = sprintf('Coarse Pose Estimation: Small Azimuthal Change (2D rotation)')
            else
                if contains(R.rot_answer, '2D')
                    grid_text{5} = sprintf('Coarse Pose Estimation: Large Azimuthal Change - do 2D transformation and stop when rotation angle > 5deg.')
                elseif contains(R.rot_answer, '3D')
                    grid_text{5} = sprintf('Coarse Pose Estimation: Large Azimuthal Change - do 3D transformation - noisier')
                end % if contains(R.rot_answer, '2D')
            end % if all(abs([R.MinuteRate_OGFrame.RotationAngle]) < 5)
        elseif ind_scp_method == 2
            grid_text{5} = sprintf('Using SCPs.')
        end % if ind_scp_method == 1

        grid_text{6} = sprintf('Extract data at %i Hz. ', extract_Hz)
        grid_text{7} = sprintf('Products to produce:')
        
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
        if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Input Data'], grid_text, grid_plot)
        end

        close all
    end % for ff = 1:length(flights)
end % for dd = 1:length(data_files)
clearvars -except *_dir user_email data_files
cd(global_dir)

