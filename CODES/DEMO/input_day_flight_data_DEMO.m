%% input_day_flight_data_DEMO
% input_day_flight_data returns all user-specified required input data for the UAV_automated_rectification toolbox.
%% Description
%
%   Inputs:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%           day_files (structure) : folders of the days to process - requires day_files.folder and day_files.name
%
%   Returns:
%     for each day:
%           cameraParams* (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%           extract_Hz (double) : extraction frame rate (Hz) - obtained from Products
%           flights (structure) : folders of the flights to process - requires flights.folder and flights.name
%           drone_type (string) : drone type (e.g. DJI) - used for file prefix
%           tz (string) : user-selected Internet Assigned Numbers Authority (IANA) time zone accepted by the datetime function
%           Products (structure) : Data products
%                       productType (string) : 'cBathy', 'Timestack', 'yTransect'
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
%
%     for each flight:
%           R (structure) : extrinsics/intrinsics information
%                       intrinsics (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%                       I (uint8 image) : undistorted initial frame
%                       world_gcp (double) : [n x 3] ground control location in world coordinate frame (x,y,z)
%                       image_gcp (double) : [n x 2] ground control location in initial frame
%                       worldPose (rigidtform3d) : orientation and location of camera in world coordinates, based off ground control location (pose, not extrinsic)
%                       mask (logical) : mask over ocean region (same dimensions as image) - used to speed up computational time (optional)
%                       feature_method (string): feature type to use in feature detection algorithm (default: `SIFT`, must be `SIFT`, `SURF`, `BRISK`, `ORB`, `KAZE`) (optional)
%
%
% Requires: exiftool (https://exiftool.org/) OR metadata .csv
%
%
%% Function Dependenies
% select_timezone
% user_input_products
% get_metadata
% find_file_format_id
% select_survey_gcp
% select_image_gcp
% select_target_gcp
% define_ocean_mask
% apply_binary_mask
% plot_grid
% define_grid
% plot_xtransect
% define_xtransect
% plot_transect
% define_ytransect
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jan 2024;

%% Data

if ~exist('global_dir', 'var') || ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
    disp('Missing global_dir and day_files. Please load in processing_run_DD_Month_YYYY.mat that has the day folders that you would like to process. ')
    [temp_file, temp_file_path] = uigetfile(pwd, 'processing_run_.mat file');
    load(fullfile(temp_file_path, temp_file)); clear temp_file*
    assert(isfolder(global_dir),['Error (get_products): ' global_dir 'doesn''t exist.']);

    if ~exist('global_dir', 'var')
        disp('Please select the global directory.')
        global_dir = uigetdir('.', 'UAV Rectification');
        cd(global_dir)
    end
    if ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
        disp('Choose DATA folder.')
        disp('For DEMO: ''DATA'' ')
        data_dir = uigetdir('.', 'DATA Folder');

        day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
        [ind_datafiles,~] = listdlg('ListString',{day_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'}, 'ListSize', [500 300]);
        day_files = day_files(ind_datafiles);
    end
end % if exist('global_dir', 'var')

%% ===========================testEmail=========================================
%                  Confirm test email recieved
%                   - TODO Change setting for SMTP server
%  =====================================================================
answer = questdlg('Did you get the test email?','Test email check', 'Yes', 'No', ' Don''t want it', 'Yes');
switch answer
    case 'No'
        disp('Please check email settings to proceed.')
        user_email = inputdlg({'Name', 'Email'});

        props = java.lang.System.getProperties;
        props.setProperty('mail.smtp.port', '587');
        props.setProperty('mail.smtp.auth','true');
        props.setProperty('mail.smtp.starttls.enable','true');

        setpref('Internet','SMTP_Server','smtp.gmail.com');
        setpref('Internet','SMTP_Username','coastallens1903');
        setpref('Internet', 'SMTP_Password', 'krrq pufl tqcp hjrw')
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
%                               - confirm initial drone position and pose from gcps
%                               - specify ocean mask to reduce processing time
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
    disp('For DEMO: This is under DATA/20211215_Torrey/day_config_file.mat.')
    disp('We recommend going through all the steps without loading the configuration file.')
    input_answer = questdlg('Do you have a ''day_config_file.mat'' configuration file?','Config File', 'Yes - Load it', 'No - Create Now', 'No - Create Now');
    switch input_answer
        case 'Yes - Load it'
            disp('Load in day configuration file.')
            [temp_file, temp_file_path] = uigetfile(global_dir, 'Input File');
            load(fullfile(temp_file_path, temp_file)); clear temp_file*
    end % switch input_answer

    %% ==========================DroneType=========================================
    %                                                    Choose drone system
    %  =============================================================================
    if ~exist('drone_type', 'var') || ~isstring(drone_type)
        disp('For DEMO: DJI')
        [ind_drone, ~] = listdlg('ListString',[{'DJI'}, {'Other'}], 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'What drone platform was used?'}, 'ListSize', [500 300]);
        if ind_drone == 1
            drone_type = "DJI";
        else
            drone_type = string(inputdlg({'What drone system?'}));
        end % if ind_drone == 1
    end %  if ~exist('drone_type', 'var') || ~isstring(drone_type)

    clear ind_drone
    %% ==========================TimeZone==========================================
    %                                        Choose timezone of video recordings
    %  =============================================================================
    if ~exist('tz', 'var') || ~ischar(tz)
        disp('For DEMO: America/Los_Angeles')
        [tz] = select_timezone;
    end %  if ~exist('tz', 'var') || ~ischar(tz)
    %% ==========================intrinsics==========================================
    %                                   Choose intrinsics file for each day of flight
    %  ==============================================================================
    if  (~exist('cameraParams_undistorted', 'var') && ~exist('cameraParams_distorted', 'var'))
        if ~exist('cameraParams', 'var')
            answer = questdlg('Has the camera been calibrated?', 'Camera Calibration', 'Yes', 'No', 'Yes');
            switch answer
                case 'Yes'
                    disp('Load in camera calibration file.')
                    disp('For DEMO: under demo_files/cameraParams_whitecap.mat')
                    [temp_file, temp_file_path] = uigetfile(global_dir, 'Camera Parameters');
                    load(fullfile(temp_file_path, temp_file)); clear temp_file*

                    % If CIRN intrinsics used as input
                    if (~exist('cameraParams', 'var') && ~exist('cameraParams_undistorted', 'var') && ~exist('cameraParams_distorted', 'var')) && exist('intrinsics', 'var')
                        cameraParams = cameraIntrinsics([intrinsics(5) intrinsics(6)], [intrinsics(3) intrinsics(4)], [intrinsics(2) intrinsics(1)], 'RadialDistortion', [intrinsics(7) intrinsics(8) intrinsics(9)], 'TangentialDistortion', [intrinsics(10) intrinsics(11)]);
                    elseif (~exist('cameraParams', 'var') && ~exist('cameraParams_undistorted', 'var') && ~exist('cameraParams_distorted', 'var')) && ~exist('intrinsics', 'var')
                        disp('Load in camera calibration file.')
                        disp('For DEMO: under demo_files/cameraParams_whitecap.mat') %% XXX
                        [temp_file, temp_file_path] = uigetfile(global_dir, 'Camera Parameters');
                        load(fullfile(temp_file_path, temp_file)); clear temp_file*
                    end % if (~exist('cameraParams', 'var') && ~exist('cameraParams_undistorted', 'var') && ~exist('cameraParams_distorted', 'var')) && exist('intrinsics', 'var')

                    if exist('cameraParams', 'var') || (exist('cameraParams_undistorted', 'var') && exist('cameraParams_distorted', 'var'))
                        % otherwise check that class is cameraIntrinsics
                        if exist('cameraParams', 'var')
                            assert(isa(cameraParams,'cameraParameters') || isa(cameraParams, 'cameraIntrinsics'), 'Error (input_day_flight_data): Please install the Computer Vision Toolbox and rerun.')
                            if isa(cameraParams, 'cameraParameters')
                                cameraParams = cameraParams.Intrinsics;
                            end %  if isa(cameraParams, 'cameraParameters')
                        else
                            assert(isa(cameraParams_undistorted, 'cameraParameters') || isa(cameraParams_undistorted,'cameraIntrinsics'), 'Error (input_day_flight_data): Please install the Computer Vision Toolbox and rerun.')
                            if isa(cameraParams_undistorted, 'cameraParameters')
                                cameraParams_undistorted = cameraParams_undistorted.Intrinsics;
                            end %  if isa(cameraParams_undistorted, 'cameraParameters')
                            if isa(cameraParams_distorted, 'cameraParameters')
                                cameraParams_distorted = cameraParams_distorted.Intrinsics;
                            end % if isa(cameraParams_distorted, 'cameraParameters')
                        end %  if exist('cameraParams', 'var')
                    end % if exist('cameraParams', 'var') || (exist('cameraParams_undistorted', 'var') && exist('cameraParams_distorted', 'var'))
                case 'No'
                    disp('Please calibrate camera to proceed.')
                    cameraCalibrator
                    return
            end % switch answer
            clear answer
        end % if ~exist('cameraParams', 'var')
    end % if  (~exist('cameraParams_undistorted', 'var') && ~exist('cameraParams_distorted', 'var'))

    %% ==========================product===========================================
    %                          DEFINE PRODUCT TYPE
    %                           - Do you already have a product file - as made from user_input_products.m
    %                               - If so, can load that in
    %                           - Define origin of grid and products to be made
    %  ==============================================================================
    if ~exist('Products', 'var') || ~isstruct(Products)
        disp('For DEMO: under demo_files/Products_Torrey.mat')
        disp('We recommend going through the steps without loading in the Products file.')
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

    end % if ~exist('Products', 'var') || ~isstruct(Products)
    %% ==========================extractionRate======================================
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
        end % if rem(max(info_Hz), info_Hz(hh)) == 0
    end % or hh = 1:length(info_Hz)
    clear hh info_Hz ans
    %% ==========================saveDayData=======================================
    %                          SAVE DAY RELEVANT DATA
    %                           - Save camera intrinsics, extraction frame rates, products, flights for specific day, drone type and timezone
    %  ==============================================================================
    flights = dir(fullfile(day_files(dd).folder, day_files(dd).name)); flights([flights.isdir]==0)=[];
    flights(contains({flights.name}, '.'))=[]; flights(contains({flights.name}, 'GCP'))=[];

    save(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'),...
        'cameraParams*', 'extract_Hz', 'Products', 'flights', 'drone_type', 'tz')

    %% =============================================================================
    %                          PROCESS EACH FLIGHT
    %  ==============================================================================
    for ff = 1 : length(flights)
        %% ========================Housekeeping=======================================
        clearvars -except dd ff *_dir user_email day_files flights
        load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'))
        assert(exist('extract_Hz', 'var'), 'Error (input_day_flight_data): extract_Hz must exist and be stored in ''day_input_data.mat''.')
        assert(isa(extract_Hz, 'double'), 'Error (input_day_flight_data): extract_Hz must be a double or array of doubles.')
        assert(exist('tz', 'var'), 'Error (input_day_flight_data): tz (timezone) must exist and be stored in ''day_input_data.mat''.')
        assert(isa(tz, 'char'), 'Error (input_day_flight_data): tz (timezone) must be a timezone character string. run [tz] = select_timezone.')

        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        disp(oname)
        cd(odir)
        if ~exist(fullfile(odir, 'Processed_data'), 'dir')
            mkdir 'Processed_data'
        end %  if ~exist(fullfile(odir, 'Processed_data'), 'dir')

        %% ========================metadata===========================================
        %                          INITIAL DRONE COORDINATES FROM METADATA
        %                           - Use exiftool to pull metadata from images and video
        %                               - mov_id indicates which movies to use in image extraction
        %                               - get initial camera position and pose from metadata
        %  ============================================================================
        % Determine file name prefix if necessary.
        if exist('drone_type', 'var') && contains(drone_type, 'DJI')
            drone_file_name = 'DJI';
        else
            drone_file_name = char(string(inputdlg({'What is the file prefix? Leave empty if starts with number.'})));
        end % if exist('drone_type', 'var') && contains(drone_type, 'DJI')

        % extract metadata % check if csv file was created with metadata - if not install exiftool
        if  ~isfile(fullfile(odir, 'Processed_data', [oname '.csv']))
            if ~isempty(drone_file_name)
                [C] = get_metadata(odir, oname, file_prefix = drone_file_name, save_dir = fullfile(odir, 'Processed_data'));
            else
                [C] = get_metadata(odir, oname, save_dir = fullfile(odir, 'Processed_data'));
            end % if size(drone_file_name,2) ~= 1
        else
            C=readtable(fullfile(odir, 'Processed_data', [oname '.csv']));
        end % if  ~isfile(fullfile(odir, 'Processed_data', [oname '.csv']))

        % check if csv file was created with metadata - if not install exiftool
        if ~isfile(fullfile(odir, 'Processed_data', [oname '.csv'])) || isempty(C)
            answer2 = questdlg('Please download and install exiftool before proceeding or create a metadata csv.', '', 'Done', 'Done');
            if  ~isfile(fullfile(odir, 'Processed_data', [oname '.csv']))
                if ~isempty(drone_file_name)
                    [C] = get_metadata(odir, oname, file_prefix = drone_file_name, save_dir = fullfile(odir, 'Processed_data'));
                else
                    [C] = get_metadata(odir, oname, save_dir = fullfile(odir, 'Processed_data'));
                end % if size(drone_file_name,2) ~= 1
            else
                C=readtable(fullfile(odir, 'Processed_data', [oname '.csv']));
            end % if  ~isfile(fullfile(odir, 'Processed_data', [oname '.csv']))
        end % if ~isfile(fullfile(odir, 'Processed_data', [oname '.csv']))


        % find jpg/mov id's -> check if files loading
        [jpg_id] = find_file_format_id(C, file_format = {'JPG', 'PNG'});
        [mov_id] = find_file_format_id(C, file_format = {'MOV', 'MP4', 'TS'});
        if isempty(mov_id)
            answer2 = questdlg('Please load a video file into the folder before proceeding.', '', 'Done', 'Done');
            if  ~isfile(fullfile(odir, 'Processed_data', [oname '.csv']))
                if ~isempty(drone_file_name)
                    [C] = get_metadata(odir, oname, file_prefix = drone_file_name, save_dir = fullfile(odir, 'Processed_data'));
                else
                    [C] = get_metadata(odir, oname, save_dir = fullfile(odir, 'Processed_data'));
                end % if size(drone_file_name,2) ~= 1
            else
                C=readtable(fullfile(odir, 'Processed_data', [oname '.csv']));
            end % if  ~isfile(fullfile(odir, 'Processed_data', [oname '.csv']))

            [jpg_id] = find_file_format_id(C, file_format = {'JPG', 'PNG'});
            [mov_id] = find_file_format_id(C, file_format = {'MOV', 'MP4', 'TS'});
        end % if isempty(mov_id)

        % if image taken at beginning & end of flight - use beginning image
        if length(jpg_id) > 1; jpg_id = jpg_id(1); end
        % if no image taken, use mov_id
        if isempty(jpg_id); jpg_id = mov_id(1); end

        % CONFIRM VIDEOS TO PROCESS
        [id, ~] = listdlg('ListString', append(string(C.FileName(mov_id)), ' - ',  string(C.Duration(mov_id))), 'SelectionMode','multiple', 'InitialValue', 1:length(mov_id), 'PromptString', {'What movies do you want to use? (command + for multiple)'}, 'ListSize', [500 300]);
        mov_id = mov_id(id);

        save(fullfile(odir, 'Processed_data', 'Initial_coordinates'), 'jpg_id', 'mov_id', 'C', 'tz')

        clearvars answer2 id drone_file_name drone_type jpg_id
        %% ========================initialFrame=========================================
        %                          EXTRACT INITIAL FRAME
        %                           - Use ffmpeg tool to extract first frame to be used for distortion and product location check
        %  ============================================================================
        if ~exist(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'), 'file')
            if ispc
                system(['ffmpeg -ss 00:00:00 -i ' char(string(C.FileName(mov_id(1)))) ' -frames:v 1 -loglevel quiet -stats -qscale:v 2 Processed_data\Initial_frame.jpg']);
            else
                system(['ffmpeg -ss 00:00:00 -i ' char(string(C.FileName(mov_id(1)))) ' -frames:v 1 -loglevel quiet -stats -qscale:v 2 Processed_data/Initial_frame.jpg']);
            end % ispc
        end % if ~exist(fullfile(odir, 'Processed_data', 'Initial_frame.jpg'), 'file')
        assert(isfile(fullfile(odir, 'Processed_data', 'Initial_frame.jpg')), 'Error (input_day_flight_data): Please install ffmpeg. Problem extracting initial frame.')
        clear C mov_id
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
        if exist('cameraParams_distorted', 'var') && exist('cameraParams_undistorted', 'var')
            assert(isa(cameraParams_distorted, 'cameraIntrinsics'), 'Error (input_day_flight_data): cameraParams_distorted must be a cameraIntrinsics object.')
            assert(isa(cameraParams_undistorted, 'cameraIntrinsics'), 'Error (input_day_flight_data): cameraParams_undistorted must be a cameraIntrinsics object.')

            J1 = undistortImage(I, cameraParams_distorted);
            J2 = undistortImage(I, cameraParams_undistorted);
            hFig = figure(1);clf
            montage({I, J1, J2}, 'Size', [1 3])
            text(1/6, 0.95, 'Original 1st frame', 'FontSize', 14, 'Units', 'normalized', 'HorizontalAlignment','center', 'BackgroundColor', [0.8 0.8 0.8])
            text(3/6, 0.95, 'Distortion Correction OFF', 'FontSize', 14, 'Units', 'normalized', 'HorizontalAlignment','center', 'BackgroundColor', [0.8 0.8 0.8])
            text(5/6, 0.95, 'Distortion Correction ON', 'FontSize', 14, 'Units', 'normalized', 'HorizontalAlignment','center', 'BackgroundColor', [0.8 0.8 0.8])
            disp('For Demo: select ''Onboard distortion correction ON''. We require the horizon to be straight.')
            [ind_distortion,tf] = listdlg('ListString',[{'Onboard distortion correction OFF'}, {'Onboard distortion correction ON'}, {'Recalibrate Camera'}], 'SelectionMode','single', 'InitialValue',2, 'PromptString', {'Distortion correction On/Off?'}, 'ListSize', [500 300]);
            if ind_distortion == 1
                cameraParams = cameraParams_distorted;
                clf;imshow(J1); imwrite(J1, fullfile(odir, 'Processed_data', 'undistortImage.png'), 'png')
            elseif ind_distortion == 2
                cameraParams = cameraParams_undistorted;
                clf;imshow(J2); imwrite(J2, fullfile(odir, 'Processed_data', 'undistortImage.png'), 'png')
            elseif ind_distortion == 3
                disp('Please recalibrate camera or check that correct intrinsics file is used.')
                return
            end % if ind_distortion == 1

            % if only 1 cameraParams version exists
        else
            assert(isa(cameraParams, 'cameraIntrinsics'), 'Error (input_day_flight_data): cameraParams must be a cameraIntrinsics object.')

            J1 = undistortImage(I, cameraParams);
            hFig = figure(1);clf
            imshowpair(I,J1, 'montage')

            [ind_distortion,tf] = listdlg('ListString',[{'Correctly calibrated'}, {'Recalibrate Camera'}], 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Is the camera corrected calibrated?'}, 'ListSize', [500 300]);
            if ind_distortion == 1
                clf;imshow(J1); imwrite(J1, fullfile(odir, 'Processed_data', 'undistortImage.png'), 'png')
            elseif ind_distortion == 2
                disp('Please recalibrate camera or check that correct intrinsics file is used.')
                cameraCalibrator
                return
            end % if ind_distortion == 1
        end %  if exist('cameraParams_distorted', 'var') && exist('cameraParams_undistorted', 'var')

        R.intrinsics = cameraParams;
        R.I = undistortImage(I, R.intrinsics);

        save(fullfile(odir, 'Processed_data', [oname '_IOEO']), 'R')
        clearvars I J1 J2 tf ind_distortion hFig cameraParams_*
        close all
        %% ========================GCPs==============================================
        %                          GET GCPs HERE
        %                           - Option 1: Manual from hand selection from LiDAR or SfM (airborne or local)
        %                           - Option 2: Manual from GCP targets
        %  ============================================================================
        % whichever method generates image_gcp (N x 2) and world_gcp (N x 3)
        close all
        disp('For DEMO: to start we recomment using ''Select GCP targets''.')
        [ind_gcp_option,~] = listdlg('ListString',[{'Select points from LiDAR/SfM'}, {'Select GCP targets'}],...
            'SelectionMode','single', 'InitialValue',2, 'PromptString', {'Initial GCP Method'}, 'ListSize', [500 300]);
        I = imread(fullfile(odir, 'GCP_withguides.png')); % normally R.I is used.
        if ind_gcp_option == 1 % manual selection from LiDAR
            image_fig = figure(1);clf
            main_fig = figure(2);clf
            zoom_fig =  figure(3);clf;
            [world_gcp, image_gcp] = select_survey_gcp(I, image_fig, main_fig, zoom_fig);

        elseif ind_gcp_option == 2 % manual selection of GCP targets (QCIT Toolbox)
            disp('For DEMO: Please go to ''zoom mode'', zoom into GCP1, exit ''zoom mode'',')
            disp('click on point, and repeat for all 5 GCP, in order. Then click outside the image.')
            disp('Please be careful between zoom and click mode. If an incorrect point is selected, this section must be restarted.')
            image_fig = figure(1);clf
            [image_gcp] = select_image_gcp(I, image_fig);
            if size(image_gcp,1) < 4
                fprintf('Please select a minimum of 4 GCP. Add %i more points.\n', 4-size(image_gcp,1))
                [i_gcp] = select_image_gcp(I, image_fig);
                image_gcp = [image_gcp; i_gcp];
            end

            disp('For DEMO: Under the DATA/20211215_Torrey/GCP_coordinates.txt')
            [world_gcp] = select_target_gcp;
            if size(world_gcp,1) ~= size(image_gcp,1)
                disp('Didn''t click the right number of points.')
                [world_gcp] = select_target_gcp;
            end % if size(world_gcp,1) ~= size(image_gcp,1)

        end % if ind_gcp_option == 1

        % Getting MATLAB worldPose
        try % get worldPose
            worldPose = estworldpose(image_gcp,world_gcp, R.intrinsics);
        catch % get more points
            iGCP = image_gcp; clear image_gcp
            wGCP = world_gcp; clear world_gcp
            disp('If you have selected all 5 GCPs, please select ''No more points possible''. If worldPose is not found, please reattempt this section.')
            [ind_gcp_option2,~] = listdlg('ListString',[{'Select points from LiDAR/SfM'}, {'Select GCP targets'}, {'No more points possible'}],...
                'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Requires more GCP points'}, 'ListSize', [500 300]);

            if ind_gcp_option2 == 1 % manual selection from LiDAR
                image_fig = figure(1);clf
                main_fig = figure(2);clf
                zoom_fig =  figure(3);clf;
                [world_gcp, image_gcp] = select_survey_gcp(I, image_fig, main_fig, zoom_fig);

            elseif ind_gcp_option2 == 2 % manual selection of GCP targets (QCIT Toolbox)
                image_fig = figure(1);clf
                [image_gcp] = select_image_gcp(I, image_fig);
                disp('For DEMO: Under the DATA/20211215_Torrey/GCP_coordinates.txt')
                [world_gcp] = select_target_gcp;
            elseif ind_gcp_option2 == 3 % no other option
                image_gcp = [];
                world_gcp=[];
            end % if ind_gcp_option2 == 1

            image_gcp = [iGCP; image_gcp];
            world_gcp = [wGCP; world_gcp];
            try
                worldPose = estworldpose(image_gcp,world_gcp, R.intrinsics);
            catch
                try
                    worldPose = estworldpose(image_gcp,world_gcp, R.intrinsics, 'MaxReprojectionError',5);
                catch
                    try
                        worldPose = estworldpose(image_gcp,world_gcp, R.intrinsics, 'MaxReprojectionError',10);
                    catch
                        worldPose = rigidtform3d(eul2rotm([0 0 0]), [0 0 0]);
                        disp('World Pose not found.')
                        if exist('user_email', 'var')
                            sendmail(user_email{2}, [oname '- World Pose not found'])
                        end % if exist('user_email', 'var')
                    end % try
                end % try
            end % try
        end % try

        hGCP = figure(3);clf
        imshow(R.I)
        hold on
        scatter(image_gcp(:,1), image_gcp(:,2), 100, 'r', 'filled')
        for ii = 1:length(image_gcp)
            text(image_gcp(ii,1)+25, image_gcp(ii,2)-25, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
        end % for ii = 1:length(image_gcp)
        iP = world2img(world_gcp,pose2extr(worldPose),R.intrinsics);
        scatter(iP(:,1), iP(:,2), 50, 'y', 'LineWidth', 3)

        R.image_gcp = image_gcp;
        R.world_gcp = world_gcp;
        R.worldPose = worldPose;

        save(fullfile(odir, 'Processed_data', [oname '_IOEO']), 'R', '-append')
        print(hGCP, '-dpng', fullfile(odir, 'Processed_data', 'gcp.png'))

        close all

        clear image_gcp world_gcp iP worldPose ind_gcp_option iGCP wGCP hGCP ii ans
        %% ========================Feature Detection Region & Method =====================

        disp('For DEMO: Please leave as SIFT Features.')
        feature_types = {'SIFT', 'BRISK', 'ORB', 'KAZE'};
        [ind_type,~] = listdlg('ListString', feature_types, 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Which feature types do you want to use?(default: SIFT)',''}, 'ListSize',[500 300]);
        R.feature_method = feature_types{ind_type};

        disp('For DEMO: Click on beach points within the prompted red zone.')
        disp('This masks out the ocean and improves processing time.')
        [R.mask] = select_ocean_mask(R.I);
        clf
        [Itemp] = apply_binary_mask(R.I, R.mask);
        image(Itemp)
        pause(0.5)
        clear Itemp ind_type feature_types
        save(fullfile(odir, 'Processed_data', [oname '_IOEO']),'R', '-append')
        close all
        %% ========================SCP================================================
        input_answer = questdlg('Do you have to also run with stabilty control points method - requires bright or dark targets in the field of view?','SCP', 'Yes - compare methods', 'No - only demo', 'No - only demo');
        switch input_answer
            case 'No - only demo'
                R.scp_flag = 0;
            case 'Yes - compare methods'
                R.scp_flag = 1;
                disp('Please make sure to have downloaded the CIRN QCIT Toolbox.')
                disp('Please select CIRN QCIT Toolbox directory.')
                cirn_dir = uigetdir('.', 'Choose CIRN QCIT Toolbox directory.');
                addpath(genpath(cirn_dir))

                % CIRN format intrinsics
                R.intrinsics_CIRN(1) =  R.intrinsics.ImageSize(2);                       % Number of pixel columns
                R.intrinsics_CIRN(2) = R.intrinsics.ImageSize(1);                        % Number of pixel rows
                R.intrinsics_CIRN(3) = R.intrinsics.PrincipalPoint(1);                   % U component of principal point
                R.intrinsics_CIRN(4) = R.intrinsics.PrincipalPoint(2);                   % V component of principal point
                R.intrinsics_CIRN(5) = R.intrinsics.FocalLength(1);                     % U components of focal lengths (in pixels)
                R.intrinsics_CIRN(6) = R.intrinsics.FocalLength(2);                     % V components of focal lengths (in pixels)
                R.intrinsics_CIRN(7) = R.intrinsics.RadialDistortion(1);                % Radial distortion coefficient
                R.intrinsics_CIRN(8) = R.intrinsics.RadialDistortion(2);                % Radial distortion coefficient
                if length(R.intrinsics.RadialDistortion) == 3
                    R.intrinsics_CIRN(9) = R.intrinsics.RadialDistortion(3);            % Radial distortion coefficient
                else
                    R.intrinsics_CIRN(9) = 0;                                                           % Radial distortion coefficient
                end
                R.intrinsics_CIRN(10) = R.intrinsics.TangentialDistortion(1);        % Tangential distortion coefficients
                R.intrinsics_CIRN(11) = R.intrinsics.TangentialDistortion(2);        % Tangential distortion coefficients

                % CIRN extrinsics
                load(fullfile(odir, 'Processed_data', 'Initial_coordinates.mat'), 'C', 'jpg_id', 'mov_id')
                lat = char(C.GPSLatitude(jpg_id));
                lat = str2double(lat(1:10));
                long = char(C.GPSLongitude(jpg_id));
                if long(end) == 'W'
                    long = str2double(['-' long(1:11)]);
                else
                    long = str2double(long(1:11));
                end
                [zgeoid_offset] = intg2012b(code_dir, lat,long);
                [UTMNorthing, UTMEasting, ~] = ll_to_utm(lat, long);
                extrinsicsInitialGuess = [UTMEasting UTMNorthing C.AbsoluteAltitude(jpg_id)-zgeoid_offset deg2rad(C.CameraYaw(mov_id(1))+360) deg2rad(C.CameraPitch(mov_id(1))+90) deg2rad(C.CameraRoll(mov_id(1)))]; % [ x y z azimuth tilt swing]
                extrinsicsKnownsFlag= [0 0 0 0 0 0];  % [ x y z azimuth tilt swing]
                [extrinsics, ~]= extrinsicsSolver(extrinsicsInitialGuess, extrinsicsKnownsFlag,R.intrinsics_CIRN,R.image_gcp,R.world_gcp);
                R.extrinsics_scp = extrinsics;
                % defining SCP
                [scp] = define_SCP(R.I, R.image_gcp, R.intrinsics_CIRN);
                R.scp = scp;
        end

        save(fullfile(odir, 'Processed_data', [oname '_IOEO']),'R', '-append')

        %% ========================productsCheck=======================================
        %                          CHECK PRODUCTS ON INITIAL IMAGE
        %                           - Load in all required data -
        %                             extrinsics, intrinsics, initial frame, input data, products
        %  ============================================================================

        load(fullfile(odir, 'Processed_data', [oname '_IOEO']),'R')
        load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'), 'Products')
        disp('For DEMO: Tide level is 1.03.')
        tide = double(string(inputdlg({ 'z elevation (tide level in relevant datum)'}, 'Tide elevation')));
        [Products.tide]=deal(tide);

        %% ========================grid================================================
        %                          GRID
        %                           - Projects grid onto initial frame
        %                           - If unhappy, can reinput grid data
        %  ============================================================================
        ids_grid = find(ismember(string({Products.type}), 'Grid'));
        for pp = ids_grid % repeat for all grids
            gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0
                plot_grid(Products(pp), R.I, R.intrinsics, R.worldPose)
                answer = questdlg('Happy with grid projection?', 'Grid projection', 'Yes', 'No - redefine', 'Yes');
                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No - redefine'
                        disp('Please change grid.')
                        origin_grid = [Products(pp).lat Products(pp).lon, Products(pp).angle];
                        tide = Products(pp).tide;
                        [Product1] = define_grid(origin_grid);
                        Product1.tide = tide;
                        Products(pp) = Product1;

                end % switch answer
            end % while gridChangeIndex == 0
            print(gcf,'-dpng', fullfile(odir, 'Processed_data', [oname '_' char(string(pp)) '_Grid_Local.png' ]))
        end % for pp = ids_grid

        clearvars ids_grid  pp gridChangeIndex answer origin_grid Product1

        %% ========================xTransects==========================================
        %                          xTransects
        %                           - Projects all xTransects onto initial frame
        %                           - If unhappy, can reinput transect data
        %  ============================================================================
        if ~isempty(find(ismember(string({Products.type}), 'xTransect')))
            gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0
                plot_xtransects(Products, R.I, R.intrinsics, R.worldPose)
                answer = questdlg('Happy with transects?', 'Transects', 'Yes', 'No - redefine', 'Yes');
                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No - redefine'
                        disp('Please change transects.')
                        ids_xtransect = find(ismember(string({Products.type}), 'xTransect'));
                        origin_grid = [Products(ids_xtransect(1)).lat Products(ids_xtransect(1)).lon, Products(ids_xtransect(1)).angle];
                        tide = Products(ids_xtransect(1)).tide;
                        Products(ids_xtransect) = [];
                        productCounter = length(Products);
                        [Product1] = define_xtransect(origin_grid);
                        [Product1.tide] = deal(tide);
                        Products(productCounter+1:productCounter+length(Product1))=Product1;
                end % switch answer
            end % while gridChangeIndex == 0
            print(gcf,'-dpng', fullfile(odir, 'Processed_data', [oname '_xTransects.png' ]))

            clearvars  gridChangeIndex answer origin_grid Product1 productCounter
        end % if ~isempty(ffind(ismember(string({Products.type}), 'xTransect')))
        %% ========================yTransects==========================================
        %                         yTransects
        %                           - Projects all yTransects onto initial frame
        %                           - If unhappy, can reinput transect data
        %  ============================================================================
        if ~isempty(find(ismember(string({Products.type}), 'yTransect')))
            gridChangeIndex = 0; % check grid
            while gridChangeIndex == 0
                plot_ytransects(Products, R.I, R.intrinsics, R.worldPose)
                answer = questdlg('Happy with transects?', 'Transects', 'Yes', 'No - redefine', 'Yes');
                switch answer
                    case 'Yes'
                        gridChangeIndex = 1;
                    case 'No - redefine'
                        disp('Please change transects.')
                        ids_ytransect = find(ismember(string({Products.type}), 'yTransect'));
                        origin_grid = [Products(ids_ytransect(1)).lat Products(ids_ytransect(1)).lon, Products(ids_ytransect(1)).angle];
                        tide = Products(ids_ytransect(1)).tide;
                        Products(ids_ytransect) = [];
                        productCounter = length(Products);
                        [Product1] = define_ytransect(origin_grid);
                        [Product1.tide] = deal(tide);
                        Products(productCounter+1:productCounter+length(Product1))=Product1;
                end % switch answer
            end % while gridChangeIndex == 0
            print(gcf,'-dpng',fullfile(odir, 'Processed_data', [oname '_yTransects.png' ]))

            clearvars  gridChangeIndex answer origin_grid Product1 productCounter
        end %  if ~isempty(find(ismember(string({Products.type}), 'yTransect')))
        %% ========================email===============================================
        %                         SEND EMAIL WITH INPUT DATA
        %                           - Origin of Coordinate System
        %                           - Initial and corrected Camera Position
        %                           - worldPose and image stabilization method (2D, 3D, SCP)
        %                           - Data extraction frame rates
        %                           - Products
        %  ============================================================================
        save(fullfile(odir, 'Processed_data', [oname '_Products.mat']), 'Products', '-v7.3')

        clear grid_text grid_plot
        load(fullfile(odir, 'Processed_data', [oname '_IOEO']))
        grid_text{1} = sprintf('Lat / Long = %.2f / %.2f, Angle = %.2f deg', Products(1).lat, Products(1).lon, Products(1).angle);
        grid_text{2} = sprintf('World Pose: %.2f, %.2f, %.2f', R.worldPose.Translation);

        grid_text{3} = sprintf('Extract data at %i Hz. ', extract_Hz);
        grid_text{4} = sprintf('Products to produce:');


        grid_plot{1} = fullfile(odir ,'Processed_data', 'gcp.png');
        ids_grid = find(ismember(string({Products.type}), 'Grid'));
        ids_xtransect = find(ismember(string({Products.type}), 'xTransect'));
        ids_ytransect = find(ismember(string({Products.type}), 'yTransect'));

        for pp = ids_grid
            grid_text{length(grid_text)+1} = sprintf('Type = %s, frameRate = %i Hz, xlim = [%i %i], ylim = [%i %i], (dx,dy) = [%.1f %.1f] m', Products(pp).type, Products(pp).frameRate, Products(pp).xlim(1), Products(pp).xlim(2), Products(pp).ylim(1), Products(pp).ylim(2), Products(pp).dx, Products(pp).dy);
            grid_plot{length(grid_plot)+1} =fullfile(odir ,'Processed_data', [oname '_' char(string(pp)) '_Grid_Local.png' ]);
        end % for pp = ids_grid
        for pp = ids_xtransect
            grid_text{length(grid_text)+1} = sprintf('Type = %s, frameRate = %i Hz, xlim = [%i %i], y = %.1f m, dx = %.1f m', Products(pp).type, Products(pp).frameRate, Products(pp).xlim(1), Products(pp).xlim(2), Products(pp).y, Products(pp).dx);
        end % for pp = ids_xtransect
        for pp = ids_ytransect
            grid_text{length(grid_text)+1} = sprintf('Type = %s, frameRate = %i Hz, x = %.1f m, ylim = [%i %i], dy = %.1f m', Products(pp).type, Products(pp).frameRate, Products(pp).x, Products(pp).ylim(1), Products(pp).ylim(2), Products(pp).dy);
        end % for pp = ids_ytransect
        if ~isempty(ids_xtransect)
            grid_plot{length(grid_plot)+1} =fullfile(odir ,'Processed_data',  [oname '_xTransects.png' ]);
        end % if ~isempty(ids_xtransect)
        if ~isempty(ids_ytransect)
            grid_plot{length(grid_plot)+1} = fullfile(odir ,'Processed_data', [oname '_yTransects.png' ]);
        end % if ~isempty(ids_ytransect)
        if exist('user_email', 'var') && ~isempty(user_email)
            try
                sendmail(user_email{2}, [oname '- Input Data'], grid_text, grid_plot)
            catch
                sendmail(user_email{2}, [oname '- Input Data'], grid_text)
            end % try
        end % if exist('user_email', 'var') && ~isempty(user_email)

        close all
    end % for ff = 1:length(flights)
end % for dd = 1:length(day_files)
clearvars -except *_dir user_email day_files
cd(global_dir)
