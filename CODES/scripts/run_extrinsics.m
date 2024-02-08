%% run_extrinsics
% run_extrinsics returns the 2D projective transformation of the image to prove image stabilization through flight.
%% Description
%
%   Inputs:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%           day_files (structure) : folders of the days to process - requires day_files.folder and day_files.name
%           flights (structure) : folders of the flights to process - requires flights.folder and flights.name
%           extract_Hz (double) : extraction frame rate (Hz) - obtained from Products
%           C (table) : Table of image/video metadata (from get_metadata)
%           mov_id (array) : list of ids that match videos (MOV, MP4, TS) in metadata table (from find_file_format_id)
%           R (structure) : extrinsics/intrinsics information
%                       intrinsics (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%                       mask (logical) : mask over ocean region (same dimensions as image) - used to speed up computational time (optional)
%                       feature_method (string): feature type to use in feature detection algorithm (default: `SIFT`, must be `SIFT`, `SURF`, `BRISK`, `ORB`, `KAZE`) (optional)
%
%   Returns:
%           R (structure) : extrinsics/intrinsics information
%                       intrinsics (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%                       mask (logical) : mask over ocean region (same dimensions as image) - used to speed up computational time (optional)
%                       feature_method (string): feature type to use in feature detection algorithm (default: `SIFT`, must be `SIFT`, `SURF`, `BRISK`, `ORB`, `KAZE`) (optional)
%                       frameRate (double) : frame rate of extrinsics (Hz)
%                       t (datetime array) : [1 x m] datetime of images at various extraction rates in UTC
%                       extrinsics_2d (projtform2d) : [1 x m] 2d projective transformation of m images
%
%
% For each extraction frame rate:
%       - extract features in first frame
%       - for all subsequent images:
% 	        - detect SIFT (or other) features
% 	        - find matching features between current frame and previous frame
% 	        - find projective 2D transformation of current frame
%
%% Function Dependenies
% get_extrinsics_fd
% plot_panorama
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024;

%% Data

if ~exist('global_dir', 'var') || ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
    disp('Missing global_dir and day_files. Please load in processing_run_DD_Month_YYYY.mat that has the day folders that you would like to process. ')
    [temp_file, temp_file_path] = uigetfile(pwd, 'processing_run_.mat file');
    load(fullfile(temp_file_path, temp_file)); clear temp_file*
    assert(isfolder(global_dir),['Error (run_extrinsics): ' global_dir 'doesn''t exist.']);

    if ~exist('global_dir', 'var')
        disp('Please select the global directory.')
        global_dir = uigetdir('.', 'UAV Rectification');
        cd(global_dir)
    end
    if ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
        disp('Choose DATA folder.')
        disp('For Athina: DATA')
        data_dir = uigetdir('.', 'DATA Folder');

        day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
        [ind_datafiles,~] = listdlg('ListString',{day_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'}, 'ListSize', [500 300]);
        day_files = day_files(ind_datafiles);
    end
end % if exist('global_dir', 'var')

% check that needed files exist
for dd = 1:length(day_files)
    assert(isfile(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat')),['Error (run_extrinsics): ' fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat') ' doesn''t exist.']);
    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'flights')
    for ff = 1:length(flights)
        assert(isfile(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Inital_coordinates.mat')), ['Error (run_extrinsics): ' fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Inital_coordinates.mat') ' doesn''t exist.']);
    end
end

%% run_extrinsics
for dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'extract_Hz', 'flights')
    assert(exist('extract_Hz', 'var'), 'Error (run_extrinsics): extract_Hz must exist and be stored in ''day_input_data.mat''.')
    assert(isa(extract_Hz, 'double'), 'Error (run_extrinsics): extract_Hz must be a double or array of doubles.')
    assert(exist('flights', 'var'), 'Error (run_extrinsics): flights must exist and be stored in ''day_input_data.mat''.')
    assert(isa(flights, 'struct'), 'Error (run_extrinsics): flights must be a structure.')
    assert((isfield(flights, 'folder') && isfield(flights, 'name')), 'Error (run_extrinsics): flights must have fields .folder and .name.')

    % repeat for each flight
    for ff = 1 : length(flights)
        clearvars -except dd *_dir user_email day_files extract_Hz flights ff
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        cd(odir)

        assert(isfile(fullfile(odir, 'Processed_data', [oname '_IOEO.mat'])), ['Error (run_extrinsics): ' fullfile(odir, 'Processed_data', [oname '_IOEO.mat']) 'doesn''t exist. R variable must be stored there.'])

        for hh = 1 : length(extract_Hz)
            clear extrinsics R
            load(fullfile(odir, 'Processed_data', [oname '_IOEO']), 'R')
            assert(exist('R', 'var'), ['Error (run_extrinsics): R must exist and be stored in ''' fullfile(odir, 'Processed_data', [oname '_IOEO.mat']) '''.'])
            assert(isfield(R, 'intrinsics'), 'Error (run_extrinsics): R must contain a cameraIntrinsics object. Please add R.intrinsics and save before proceeding. ')
            assert(isa(R.intrinsics, 'cameraIntrinsics'), 'Error (run_extrinsics): intrinsics must be a cameraIntrinsics object.')

            imageDirectory = sprintf('images_%iHz', extract_Hz(hh));
            images = imageDatastore(imageDirectory);

            load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'C', 'mov_id', 'tz')
            assert(exist('C', 'var'), 'Error (run_extrinsics): C must exist and be stored in ''Initial_coordinates.mat''. run get_metadata.')
            assert(isa(C, 'table'), 'Error (run_extrinsics): C must be a table. run get_metadata.')
            assert(exist('mov_id', 'var'), 'Error (run_extrinsics): mov_id must exist and be stored in ''Initial_coordinates.mat''. run [mov_id] = find_file_format_id(C, file_format = {''MOV'', ''MP4''}).')
            assert(isa(mov_id, 'double'), 'Error (run_extrinsics): mov_id must be a double or array of doubles. run [mov_id] = find_file_format_id(C, file_format = {''MOV'', ''MP4''}).')
            assert(exist('tz', 'var'), 'Error (run_extrinsics): tz (timezone) must exist and be stored in ''Initial_coordinates.mat''. run [tz] = select_timezone.')
            assert(isa(tz, 'char') || isa(tz, 'string'), 'Error (run_extrinsics): tz (timezone) must be timezone character string. run [tz] = select_timezone.')

            R.frameRate = extract_Hz(hh);
            dts = 1/extract_Hz(hh);
            to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', tz);
            to.TimeZone = 'UTC';
            to = datenum(to);
            t = (dts./24./3600).*((1:length(images.Files))-1)+ to;
            R.t = datetime(t, 'ConvertFrom', 'datenum', 'TimeZone', 'UTC');

            %% GET EXTRINSICS
            %% ========================FeatureDetection============================================
            %           - Using neighboring images for feature detection
            %  ===================================================================================
            if isfield(R, 'mask') && ~isfield(R, 'feature_method')
                [extrinsics] = get_extrinsics_fd(images, R.intrinsics, mask=R.mask);
            elseif isfield(R, 'mask') && isfield(R, 'feature_method')
                [extrinsics] = get_extrinsics_fd(images, R.intrinsics, mask=R.mask, Method = R.feature_method);
            elseif ~isfield(R, 'mask') && isfield(R, 'feature_method')
                [extrinsics] = get_extrinsics_fd(images, R.intrinsics, Method = R.feature_method);
            elseif ~isfield(R, 'mask') && ~isfield(R, 'feature_method')
                [extrinsics] = get_extrinsics_fd(images, R.intrinsics);
            end %  if isfield(R, 'mask') && ~isfield(R, 'feature_method')
            % Create the panorama.
            [panorama, panoramaView] = plot_panorama(images, R.intrinsics, extrinsics);
            %  Save File
            figure(1);clf
            imshow(panorama)
            saveas(gca, fullfile(odir, 'Processed_data', [oname '_Panorama.png']))
            R.extrinsics_2d = extrinsics;
            R.panoramaView = panoramaView;
            save(fullfile(odir, 'Processed_data', [oname '_IOEO_' char(string(extract_Hz(hh))) 'Hz' ]),'R')

            %% ========================SCPs=====================================================
            %
            % if exist('user_email', 'var')
            %     sendmail(user_email{2}, [oname '- Please start extrinsics through time with SCPs.'])
            % end
            % answer = questdlg('Ready to start SCPs?', ...
            %     'SCPs begin',...
            %     'Yes', 'Yes');
            %
            % load(fullfile(odir, 'Processed_data', [oname '_IOEO_' char(string(extract_Hz(hh))) 'Hz' ]),'R')
            % R.intrinsics_CIRN = intrinsics_CIRN;
            % [extrinsics] = get_extrinsics_scp(odir, oname, extract_Hz(hh), images, R.scp, R.extrinsics_scp, R.intrinsics_CIRN, t, R.intrinsics);
            % R.extrinsics_scp = extrinsics;
            % save(fullfile(odir, 'Processed_data', [oname '_IOEO_' char(string(extract_Hz(hh))) 'Hz' ]),'R','-append')

        end % for hh = 1 : length(extract_Hz)
        if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Extrinsics through time DONE'])
        end % if exist('user_email', 'var')
    end % for ff = 1 : length(flights)
end % for dd = 1 : length(day_files)
clearvars -except *_dir user_email day_files
cd(global_dir)
