%% UAV_automated_rectification toolbox
%
%
% 
%   1. Housekeeping
%           Platform Detection: The script identifies the operating system (Mac, Linux, Windows).
%           Global Directory Selection: Asks the user to choose the directory for UAV rectification.
%           Path Configuration: Modifies the system's PATH environment variable.
%   2. Check Necessary Codes
%           Directory Checking: Checks if required code directories exist, prompting the user to download them if not.
%           Path Addition: Adds required code directories to MATLAB's search path.
%   3. Select Days to Process
%           Data Directory: Lists available data folders for processing.
%           User Selection: Allows the user to choose which days to process.
%   4. Confirm Update Emails and Get Email Address
%           Email Confirmation: Asks the user if they want to receive update emails.
%           Email Setup: Configures email parameters and sends a test email if requested.
%           Data Logging: Saves processing details and user input for the current run.
%   5. User Input Section
%           Camera Intrinsics: User inputs camera intrinsics file and related details.
%           Grid & Transect Coordinates: User inputs or loads grid and transect coordinates.
%           Coordinate System: User specifies local or world coordinates and pixel size (dx).
%   6. Image Extraction
%           Data Dependency: Requires data_files and user_email variables.
%           Image Extraction: Uses FFmpeg to extract images from video files.
%           Email Notification: Sends an email when image extraction is complete.
%   7. Extrinsics Through Time (Currently commented out)
%           Data Dependency: Requires data_files and user_email variables.
%           Extrinsic Calibration: Determines camera pose from frame to frame using various methods like horizon tracking, drone metadata, or feature detection. This section is currently commented out.
%       - Platform Detection
%
%
%
%
%  Housekeeping
%       - confirm DATA path - which day or multiple days are you processing
%       - get user email 
%
%  User Input
%       - Obtain day relevant data 
%               - camera intrinsics
%               - Products
%               - extraction frame rates
%       - Do flight specific checks
%               - Pull initial drone position and pose from metadata (using exiftool)
%               - extract initial frame (using ffmpeg)
%               - confirm distortion
%               - confirm inital drone position and pose from gcps
%                       - using LiDAR/SfM survey
%                       - using GoogleEarth
%                       - using GCPs (targets / objects in frame)
%               - check products
%
%  Extract Images
%       - Repeat for each day + flight
%               - For each extraction frame rate:
%                   - make Hz directory for images
%                   - for every movie to be extracted: extract images from video at extraction frame rate using ffmpeg (into seperate folder intially)
%                   - move images from movie folders into group folder and rename sequentially
%               - Send email that image extraction complete
%
% Run Extriniscs
%    - Repeat for each day + flight
%           - Option for SCPs (adapted from CIRN QCIT F_variableExtrinsicSolutions.m)
%           - Use information in least squares fitting approximation to
%           determine camera pose from frame to frame
%               - Options include: 
%                   - Horizon tracking
%                   - Drone metadata
%                   - Feature detection
%
% Get Products
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%% ====================================================================
%                          Housekeeping         
%                           - confirm CODES path
%                           - confirm DATA path - which day or multiple days are you processing
%                           - get user email 
%  =====================================================================
%% =============== Get global directory location. =====================================================================
clearvars

if ismac
    % Code to run on Mac platform
    platform = 'mac'
elseif isunix
    % Code to run on Linux platform
    platform = 'linux'
elseif ispc
    % Code to run on Windows platform
    platform = 'windows'
else
    disp('Platform not supported')
end

if ismac || isunix
    disp('Choose UAV Rectification folder.')
    disp('For Athina: Athina_Automated_rectification_work') %% XXX
end
global_dir = uigetdir('.', 'UAV Rectification');
cd(global_dir)
setenv('PATH', [getenv('PATH') ':/usr/local/bin']);

%% =============== Check that all necessary codes are loaded. =====================================================================
% Check for CODES folder dependencies
code_dir = fullfile(global_dir, 'UAV_automated_rectification', 'CODES');

% Check that required rectification codes are downloaded.
if ~exist(fullfile(code_dir, 'CIRN'), 'dir')
    disp('Please download CIRN codes from GitHub.')
end
% Check that cBathy codes are downloaded.
if ~exist(fullfile(code_dir, 'cBathy_2.0'), 'dir')
    disp('Please download cBathy v2.0 codes from GitHub.')
end
% Check that basic Functions are downloaded.
if ~exist(fullfile(code_dir, 'basicFunctions'), 'dir')
    disp('Please download basicFunctions codes from GitHub.')
end

% Check that helper Functions are downloaded.
if ~exist(fullfile(code_dir, 'helperFunctions'), 'dir')
    disp('Please download helperFunctions codes from GitHub.')
end

% Check that ffmpeg is installed.
system(['ffmpeg -version'])
ffmpeg_answer = questdlg('Is ffmpeg installed?','ffmpeg Installation', 'Yes', 'No', 'Yes');
switch ffmpeg_answer
    case 'No'
        disp('Please go to https://ffmpeg.org/ and install ffmpeg before proceeding.')
        system(['ffmpeg -version'])
        ffmpeg_answer = questdlg('Is ffmpeg installed now?','ffmpeg Installation', 'Yes', 'No', 'Yes');
end

% Check that exiftool is installed.
exiftool_answer = questdlg('Is exiftool installed?','exiftool Installation', 'Yes', 'No', 'Yes');
switch exiftool_answer
    case 'No'
        disp('Please go to https://exiftool.org and install exiftool before proceeding.')
        ffmpeg_answer = questdlg('Is exiftool installed now?','exiftool Installation', 'Yes', 'No', 'Yes');
end

addpath(genpath(code_dir))

%% =============== Select days to process.  =====================================================================
% Load which data folders are to be processed
if ismac || isunix
    disp('Choose DATA folder.')
    disp('For Athina: DATA') %% XXX
end
data_dir = uigetdir('.', 'DATA Folder');

% Load in all days that need to be processed.
data_files = dir(data_dir); data_files([data_files.isdir]==0)=[]; data_files(contains({data_files.name}, '.'))=[];
[ind_datafiles,~] = listdlg('ListString',{data_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'});
data_files = data_files(ind_datafiles);

%% =============== Confirm update emails and get email address. =====================================================================
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
            setpref('Internet','SMTP_Username','athinalange1996');
            setpref('Internet', 'SMTP_Password', 'baundwhnctgbsykb')
            sendmail(user_email{2}, 'UAV Toolbox test email', [user_email{1} ' is processing UAV data from ' data_files.name '.'])
            
            save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'data_files', 'user_email')
        case 'No'
            save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'data_files')

    end

%% ====================================================================
%                          USER INPUT (DAY AND FLIGHT SPECIFIC DATA)        
%                           - Choose camera intrinsics file (all flights for a given day must be used with the same drone)
%                           - Grid & transect coordinates - can be input or from file
%                           - Local or world coordinates?
%                           - dx
%  =====================================================================
user_input_data
% change to day_flight_input_data
%% ====================================================================
%                           EXTRACT IMAGES       
%                           - requires data_files and user_email (if emails wanted)
%                           - requires ffmpeg to extract images
%  =====================================================================
extract_images_from_UAV

%% ====================================================================
%                           EXTRINSICS THROUGH TIME       
%                           - requires data_files and user_email (if emails wanted)
%                           - requires XXX
%  =====================================================================
run_extrinsics

%% ====================================================================
%                           EXTRACT PRODUCTS
%                           - requires data_files and user_email (if emails wanted)
%                           - requires XXX
%  =====================================================================
get_products
[iDark, iBright, iTimex] = makeARGUSproducts(images, R.FullRate_OGFrame, intrinsics)