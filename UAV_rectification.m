%% UAV_automated_rectification toolbox
%   1. Housekeeping
%           Global Directory Selection: Asks the user to choose the root directory for UAV rectification.
%           Directory Checking: Checks if required code directories and MATLAB toolboxes exist, prompting the user to download them if not. Adds required code directories to MATLAB's search path
%           Folder Selection: Allows the user to choose which days to process.
%   2. User Input Section
%           Camera Intrinsics: User inputs camera intrinsics file and related details.
%           Products Definition: User inputs or loads grid and transect coordinates.
%           Initial Camera Extrinsics: Use ground control points to define camera world pose.
%   3. Image Extraction
%           Image Extraction: Uses FFmpeg to extract images from video files.
%   4. Extrinsics Through Time
%           Extrinsics: Determines camera pose from frame to frame using SIFT feature detection. 
%   5. Create Products
%           Pixel Extraction: Stabilize image and extract pixels for Products.
%           ARGUS Products: Create Timex, Bright, Dark products
%   6. Save Products (optional)
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
%                       mask (logical) : mask over ocean region (same dimensions as image) - used to speed up computational time (optional)
%                       feature_method (string): feature type to use in feature detection algorithm (default: `SIFT`, must be `SIFT`, `SURF`, `BRISK`, `ORB`, `KAZE`) (optional)
%                       frameRate (double) : frame rate of extrinsics (Hz)
%                       t (datetime array) : [1 x m] datetime of images at various extraction rates in UTC
%                       extrinsics_2d (projtform2d) : [1 x m] 2d projective transformation of m images
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
% input_day_flight_data
% extract_images_from_UAV
% stabilize_video
% get_products
% save_products
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
    disp('Choose global (repository) folder - ''CoastalLens''.')
    setenv('PATH', [getenv('PATH') ':/usr/local/bin']);
end
global_dir = uigetdir('.', 'Choose global (repository) folder - ''CoastalLens''.');
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

% Check that ffmpeg is installed.
ffmpeg_answer = questdlg('Is ffmpeg installed? ','ffmpeg Installation', 'Yes', 'No', 'Yes');
switch ffmpeg_answer
    case 'No'
        disp('Please go to https://ffmpeg.org/ and install ffmpeg before proceeding.')
        system(['ffmpeg -version'])
        ffmpeg_answer = questdlg('Is ffmpeg installed now?','ffmpeg Installation', 'Yes', 'No', 'Yes');
end % switch ffmpeg_answer

% Check that exiftool is installed.
exiftool_answer = questdlg('Is exiftool installed?','exiftool Installation', 'Yes', 'No', 'Yes');
switch exiftool_answer
    case 'No'
        disp('Please go to https://exiftool.org and install exiftool before proceeding.')
        ffmpeg_answer = questdlg('Is exiftool installed now?','exiftool Installation', 'Yes', 'No', 'Yes');
end % switch exiftool_answer

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
%% =============== Select days to process.  =================================
% Load which data folders are to be processed
if ismac || isunix
    disp('Choose DATA folder.')
end
data_dir = uigetdir('.', 'DATA Folder');

% Load in all days that need to be processed.
day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
[ind_datafiles,~] = listdlg('ListString',{day_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?', ''}, 'ListSize', [500 300]);
day_files = day_files(ind_datafiles);

%% =============== Confirm update emails and get email address. ===============
% Get user email
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
        sendmail(user_email{2}, 'UAV Toolbox test email', [user_email{1} ' is processing UAV data from ' {day_files.name} ''])

        save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'day_files', 'user_email')
    case 'No'
        save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'day_files')

end

%% ====================================================================
%                          USER INPUT (DAY AND FLIGHT SPECIFIC DATA)
%                           - Choose camera intrinsics file (all flights for a given day must be used with the same drone)
%                           - Grid & transect coordinates for products- can be input or from file
%                           - GCP for initial camera pose
%  =====================================================================
input_day_flight_data

%% ====================================================================
%                           EXTRACT IMAGES
%                           - requires day_files and user_email (if emails wanted)
%                           - requires ffmpeg to extract images
%  =====================================================================
extract_images_from_UAV

%% ====================================================================
%                           STABILIZE VIDEO
%                           - requires day_files and user_email (if emails wanted)
%                           - Feature Detection (Monocular Visual Odometry) - 2D projective transformation
%  =====================================================================
stabilize_video

%% ====================================================================
%                           EXTRACT PRODUCTS
%                           - requires day_files and user_email (if emails wanted)
%  =====================================================================
get_products

%% ====================================================================
%                           SAVE PRODUCTS
%                           - requires day_files
%  =====================================================================
input_answer = questdlg('Do you want to save all the rectified images?','Save images', 'Yes', 'No', 'Yes');
switch input_answer
    case 'Yes'
        save_products
end % switch input_answer
