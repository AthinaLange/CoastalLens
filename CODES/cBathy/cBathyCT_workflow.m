%% cBathyCT workflow
%   1. Housekeeping
%           Global Directory Selection: Asks the user to choose the root directory for UAV rectification.
%           Directory Checking: Checks if required code directories and MATLAB toolboxes exist, prompting the user to download them if not. Adds required code directories to MATLAB's search path
%           Folder Selection: Allows the user to choose which days to process.
%   2. run_cBathy
%           Steps 1 & 2 (no Kalman filtering right now)
%           Holman and Bergsma 2022
%   3. save_timestacks
%           save timestacks as pngs -> then run Wave Crest Detector in terminal
%   4. run_cbathyCT
%           Lange et al. (2023)
%
%% Description
%
%   Inputs: 
%           DEM
%           Products - from UAV_rectification or ARGUS_rectification
%
%
%   Returns:
%           cBathyCT (structure) : cBathyCT results
%                       date (string) : date of product (YYYYMMDD)
%                       Iocation (string) : location name - from filename
%                       flight / cam (double) : flight number (for UAV) or camera number (for ARGUS)
%                       mop (double) : mop number
%                       x10 (array) : [0:0.1:500], 0.1m resolution - all elevation values interpolated to this x array
%                       survey (structure) : 
%                                   z (array) : [1 x length(x10)] elevation pulled from survey DEM on MOP line
%                       cbathy (structure): 
%                                   z (array) : cBathy direct output on given transect
%                                   zerr (array) : cBathy hErr
%                                   cbathy_hErr (array) : cBathy with hErr > 0.5m region interpolated over
%                                   cbathy_gamma (array) : cBathy with breaking region removed for given variable gamma(x)
%                       tide (double) : tide level - pulled from Products tide level
%                       min_tide (double) : minimum tide level of day - pulled from DEM - assuming survey taken at daily low tide
%                       crests (structure) : 
%                                   t (array) : time for wave tracks (sec)
%                                   x (array) : cross-shore location for wave tracks (m) (0 is offshore, 500 is onshore)
%                                   c (array) : phase speed of wave tracks (m/s) - interpolated to x10
%                       bp (array) : breakpoint location for each crest 
%                       xshift (double) : index (for x10) of cross-shore shift required to match subaerial survey with subaqueous bathymetry - should be small if using DEM
%                       h_avg (structure) : 
%                                   lin (array) : linear crest-tracking c = sqrt(gh)
%                                   nlin (array) : nonlinear crest-tracking  = sqrt(gh(1+0.42))
%                                   bp (array) : breakpoint transition crest-tracking c = sqrt(gh(1+gamma(x)))
%                       gamma (array) : [ x ] transition between 0 and 0.42 for each wave track 0 interpolated to x10 
%                       gamma_mean (array) : [1 x length(x10)] mean of all step function gammas 
%                       composite (structure) : constructed topobathy products with subaerial survey + 
%                                   cbathy_hErr (array) : cBathy with hErr < 0.5m
%                                   cbathy_gamma (array) : cBathy with breaking region removed
%                                   cbathy_nlin (array) : cbathy_gamma with gamma(x) correction
%                                   cbathyCT (array) : breakpoint transition crest-tracking surfzone bathymetry and cBathy offshore
%                       lims (array) : [1 x 3] index of [1st BP valid onshore point, onshore cuttoff of breaking, offshore cutoff of breaking] 
%                       Error (structure) : 
%                                   RMSE (root-mean-square error),
%                                   Skill 
%                                   Bias
%   
%
%% Function Dependenies
% run_cBathy
% save_timestacks
% run_cBathyCT
%
%% Required Toolbox
%   - cBathy 2.0
%   (https://github.com/Coastal-Imaging-Research-Network/cBathy-Toolbox)
%   - Wave Crest Detector
%   (https://github.com/AthinaLange/WaveCrestDetection)
%
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jul 2024;

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
addpath(genpath(code_dir))

if isToolboxAvailable('Image Processing Toolbox','warning')== 0
    disp('Please install the Image Processing Toolbox before proceeding.')
end % if isToolboxAvailable('Image Processing Toolbox','warning')== 0

if isToolboxAvailable('Computer Vision Toolbox','warning')== 0
    disp('Please install the Computer Vision Toolbox before proceeding.')
end % if isToolboxAvailable('Computer Vision Toolbox','warning')== 0

warning('off', 'images:geotrans:transformationMatrixBadlyConditioned')
clear *answer ans
%% =============== Select days to process.  =================================
% Load which data folders are to be processed
if ismac || isunix
    disp('Choose DATA folder.')
end
data_dir = uigetdir('.', 'DATA Folder');

camera_type = questdlg('UAV or ARGUS?', 'UAV or ARGUS?', 'UAV', 'ARGUS', 'UAV');
switch camera_type
    case 'UAV'
        % Load in all days that need to be processed.
        day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
        [ind_datafiles,~] = listdlg('ListString',{day_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?', ''}, 'ListSize', [500 300]);
        day_files = day_files(ind_datafiles);

    case 'ARGUS'
        % Load in all days that need to be processed.
        day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
        day_files(contains({day_files.name}, 'GCP'))=[]; day_files(contains({day_files.name}, 'Make_products'))=[];
        day_files(contains({day_files.name}, 'Processed_data'))=[];day_files(contains({day_files.name}, 'Products'))=[];

        if ~exist(fullfile(data_dir, 'Processed_data'), 'dir')
            mkdir(fullfile(data_dir, 'Processed_data'))
        end %  if ~exist(fullfile(data_dir, 'Processed_data'), 'dir')

        % Removes any days already processed
        processed_files = dir(fullfile(data_dir, 'Processed_data')); 
        processed_files([processed_files.isdir] == 1)=[]; 
        processed_files(~contains({processed_files.name}, 'cBathy'))=[];
        % if file already processed - don't reprocess
        if ~isempty(processed_files)
            for ii = length(day_files):-1:1
                if contains([processed_files.name], day_files(ii).name)
                    day_files(ii) = [];
                end
            end
        end
        clear processed_files ii
end % switch camera_type
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

        save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'day_files', 'user_email', 'camera_type')
    case 'No'
        save(fullfile(global_dir, ['processing_run_' char(string(datetime('today')))]), '*_dir', 'day_files', 'camera_type')

end

%% ====================================================================
%                          run_cBathy
%                           - choose cBathy 2.0 folder location
%                           - run Steps 1 and 2 of cBathy - in future can add Kalman filtering
%                           - based off of Holman and Bergsma 2022
%  =====================================================================
run_cBathy

%% ====================================================================
%                           save_timestacks
%                           - saves timestacks as png
%  =====================================================================
% save_timestacks
% mogrify -rotate 90 -flop *.png
%% ====================================================================
%                           RUN WAVE CREST DETECTOR ON TIMESTACKS
%                           - GitHub Code
%  =====================================================================
% in WaveCrestDetector folder:
% for pic in odir/Rectified_images/*; python predict.py --modelcheckpoints/ --filter-interactive 0 --image $pic; done
%% ====================================================================
%                           run_cBathyCT
%                           - takes crests on timestacks and computes
%                           cBathyCT results
%                           - based off of Lange et al. (2023)
%  =====================================================================
run_cBathyCT

