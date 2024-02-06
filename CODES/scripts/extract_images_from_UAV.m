%% extract_images_from_UAV
% extract_images_from_UAV extracts images from video files at specified frame rates for all flights on specified processing days.
%% Description
%
%   Inputs:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%           day_files (structure) : folders of the days to process - requires day_files.folder and day_files.name
%           flights (structure) : folders of the flights to process - requires flights.folder and flights.name
%           extract_Hz (double) : extraction frame rate (Hz) - obtained from Products
%           C (table) : Table of image/video metadata (from get_metadata)
%           mov_id (array) : list of ids that match videos (MOV, MP4, TS) in metadata table (from find_file_format_id)
%
%
% Requires ffmpeg (https://ffmpeg.org)
%
% For each extraction frame rate:
%           - make Hz directory for images
%           - for every movie to be extracted: extract images from video at extraction frame rate using ffmpeg (into separate folders initially)
%           - move images from movie folders into group folder and rename sequentially
%% Function Dependenies
% extract_images
% combine_images
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Sept 2023;

%% Data

if ~exist('global_dir', 'var') || ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
    disp('Missing global_dir and day_files. Please load in processing_run_DD_Month_YYYY.mat that has the day folders that you would like to process. ')
    [temp_file, temp_file_path] = uigetfile(pwd, 'processing_run_.mat file');
    load(fullfile(temp_file_path, temp_file)); clear temp_file*
    assert(isfolder(global_dir),['Error (extract_images_from_UAV): ' global_dir 'doesn''t exist.']);

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
    assert(isfile(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat')),['Error (extract_images_from_UAV): ' fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat') ' doesn''t exist.']);
    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'flights')
    for ff = 1:length(flights)
        assert(isfile(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Inital_coordinates.mat')), ['Error (extract_images_from_UAV): ' fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Inital_coordinates.mat') ' doesn''t exist.']);
    end
end

%% Extract images
for dd = 1:length(day_files)
    clearvars -except dd *_dir user_email day_files
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'extract_Hz', 'flights')
    assert(exist('extract_Hz', 'var'), 'Error (extract_images_from_UAV): extract_Hz must exist and be stored in ''day_input_data.mat''.')
    assert(isa(extract_Hz, 'double'), 'Error (extract_images_from_UAV): extract_Hz must be a double or array of doubles.')
    assert(exist('flights', 'var'), 'Error (extract_images_from_UAV): flights must exist and be stored in ''day_input_data.mat''.')
    assert(isa(flights, 'struct'), 'Error (extract_images_from_UAV): flights must be a structure.')
    assert((isfield(flights, 'folder') && isfield(flights, 'name')), 'Error (extract_images_from_UAV): flights must have fields .folder and .name.')

    % repeat for each flight
    for ff = 1: length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        cd(odir)

        load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'mov_id', 'C')
        assert(exist('C', 'var'), 'Error (extract_images_from_UAV): C must exist and be stored in ''Initial_coordinates.mat''. run get_metadata.')
        assert(isa(C, 'table'), 'Error (extract_images_from_UAV): C must be a table. run get_metadata.')
        assert(exist('mov_id', 'var'), 'Error (extract_images_from_UAV): mov_id must exist and be stored in ''Initial_coordinates.mat''. run [mov_id] = find_file_format_id(C, file_format = {''MOV'', ''MP4''}).')
        assert(isa(mov_id, 'double'), 'Error (extract_images_from_UAV): mov_id must be a double or array of doubles. run [mov_id] = find_file_format_id(C, file_format = {''MOV'', ''MP4''}).')

        video_files = dir(fullfile(day_files(dd).folder, day_files(dd).name, flights(ff).name));
        video_files(~contains({video_files.name},  C.FileName(mov_id)))=[];

        % repeat for each extracted frame rate
        for hh = 1 : length(extract_Hz)
            if ~exist(sprintf('images_%iHz', extract_Hz(hh)), 'dir')
                mkdir(sprintf('images_%iHz', extract_Hz(hh)))
                imageDirectory = sprintf('images_%iHz', extract_Hz(hh));

                % extract images at extract_Hz rate with ffmpeg
                extract_images(video_files, frameRate = extract_Hz(hh))

                % combine images extracted from video
                combine_images(video_files, imageDirectory = imageDirectory)

                % replacing 1st image with image extracted as initial frame for gcp and scp accuracy
                if ispc
                    system(['cp Processed_data\Initial_frame.jpg ' imageDirectory '\Frame_00001.jpg']);
                else
                    system(['cp Processed_data/Initial_frame.jpg ' imageDirectory '/Frame_00001.jpg']);
                end %  if ispc
            end % if ~exist(sprintf('images_%iHz', extract_Hz(hh)), 'dir')
        end % for hh = 1:length(extract_Hz)

        if exist('options.user_email', 'var')
            sendmail(options.user_email, [oname '- Image Extraction Done'])
        end % if exist('options.user_email', 'var')

    end % for ff = 1:length(flights)
end % for dd = 1:length(day_files)
clearvars -except *_dir user_email day_files
cd(global_dir)