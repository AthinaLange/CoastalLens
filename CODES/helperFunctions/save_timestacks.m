%% save_timestacks
% save_timestacks saves timestack images from Products as png's in Rectified_images folder.
%% Description
%
%   Inputs:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%           day_files (structure) : folders of the days to process - requires day_files.folder and day_files.name
%           flights (structure) : folders of the flights to process - requires flights.folder and flights.name
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
%                       z (double) : Elevation - can be empty or array of DEM values (NAVD88 m)
%                       tide (double) : Tide level (NAVD88 m)
%                       t (datetime array) : [1 x m] datetime of images at given extraction rates in UTC
%                       localX (double) : [y_length x x_length] x coordinates in locally-defined coordinate system (+x is offshore, m)
%                       localY (double) : [y_length x x_length] y coordinates in locally-defined coordinate system (+y is right of origin, m)
%                       localZ (double) : [y_length x x_length] z coordinates in locally-defined coordinate system
%                       Eastings (double) : [y x x] Eastings coordinates (m)
%                       Northings (double) : [y x x] Northings coordinates (m)
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
%
%
%   Returns:
%
%
%% Function Dependenies
% save_rectified_image
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jul 2024;

%% Data

if ~exist('global_dir', 'var') || ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
    disp('Missing global_dir and day_files. Please load in processing_run_DD_Month_YYYY.mat that has the day folders that you would like to process. ')
    [temp_file, temp_file_path] = uigetfile(pwd, 'processing_run_.mat file');
    load(fullfile(temp_file_path, temp_file)); clear temp_file*
    assert(isfolder(global_dir),['Error (save_timestacks): ' global_dir 'doesn''t exist.']);

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
    assert(isfile(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat')),['Error (save_timestacks): ' fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat') ' doesn''t exist.']);
end
%%
close all
for  dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'), 'extract_Hz', 'flights', 'DEM')
    assert(exist('extract_Hz', 'var'), 'Error (save_timestacks): extract_Hz must exist and be stored in ''day_config_file.mat''.')
    assert(isa(extract_Hz, 'double'), 'Error (save_timestacks): extract_Hz must be a double or array of doubles.')
    assert(exist('flights', 'var'), 'Error (save_timestacks): flights must exist and be stored in ''day_config_file.mat''.')
    assert(isa(flights, 'struct'), 'Error (save_timestacks): flights must be a structure.')
    assert((isfield(flights, 'folder') && isfield(flights, 'name')), 'Error (save_timestacks): flights must have fields .folder and .name.')

    % repeat for each flight
    for ff = 1 : length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        disp(oname)
        cd(odir)
        mkdir('Timestacks')

        load(fullfile(odir, 'Processed_data', [oname '_Products.mat']), 'Products')
        assert(isa(Products, 'struct'), 'Error (save_timestacks): Products must be a stucture as defined in user_input_products.')
        assert((isfield(Products, 'type') && isfield(Products, 'frameRate')), 'Error (save_timestacks): Products must be a stucture as defined in user_input_products.')

        % only want to save x_transects and y_transects
         Products(contains({Products.type}, 'Grid'))=[];
         save_rectified_image(oname, save_dir, Products)

        if exist('user_email', 'var')
            try
                sendmail(user_email{2}, [oname '- Save timestacks DONE'])
            end
        end % if exist('user_email', 'var')
    end %  for ff = 1 : length(flights)
end % for  dd = 1 : length(day_files)
close all
cd(global_dir)