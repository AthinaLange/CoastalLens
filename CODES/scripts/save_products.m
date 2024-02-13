%% save_products
% save_products saves rectified image products from Products in Rectified_images folder.
%% Description
%
%   Inputs:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%           day_files (structure) : folders of the days to process - requires day_files.folder and day_files.name
%           flights (structure) : folders of the flights to process - requires flights.folder and flights.name
%           Products (structure) : Products folder that contains uint8 images to be saved
%                       type (string) : 'Grid', 'xTransect', 'yTransect'
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
%               (optional for saved name):
%                       frameRate (double) : frame rate of product (Hz)
%                       xlim (double): [1 x 2] cross-shore limits of grid (+ is offshore of origin) (m)
%                       ylim (double) : [1 x 2] along-shore limits of grid (+ is to the right of origin looking offshore) (m)
%                       dx (double) : Cross-shore resolution (m)
%                       dy (double) : Along-shore resolution (m)
%                       x (double): Cross-shore distance from origin (+ is offshore of origin) (m)
%                       y (double): Along-shore distance from origin (+ is to the right of the origin looking offshore) (m)
%                       t (datetime array) : [1 x m] datetime of images at given extraction rates in UTC
%
%   Returns:
%
%
%
%% Function Dependenies
% save_rectified_images
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
        disp('For Athina: DATA')
        data_dir = uigetdir('.', 'DATA Folder');

        day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
        [ind_datafiles,~] = listdlg('ListString',{day_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'}, 'ListSize', [500 300]);
        day_files = day_files(ind_datafiles);
    end
end % if exist('global_dir', 'var')

% check that needed files exist
for dd = 1:length(day_files)
    assert(isfile(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat')),['Error (get_products): ' fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat') ' doesn''t exist.']);
end
%% save products
close all
for  dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files 
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'), 'extract_Hz', 'flights')
    assert(exist('flights', 'var'), 'Error (get_products): flights must exist and be stored in ''day_config_file.mat''.')
    assert(isa(flights, 'struct'), 'Error (get_products): flights must be a structure.')
    assert((isfield(flights, 'folder') && isfield(flights, 'name')), 'Error (get_products): flights must have fields .folder and .name.')

    for ff = 1 : length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        disp(oname)
        cd(odir)
        save_dir = fullfile(odir, 'Rectified_images');
         if ~exist(save_dir, 'dir')
            mkdir(save_dir)
         end % if ~exist(save_dir, 'dir')
         load(fullfile(odir, 'Processed_data', [oname '_Products.mat']), 'Products')
         save_rectified_image(oname, save_dir, Products)
         if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Save image products DONE'])
        end % if exist('user_email', 'var')
    end % for ff = 1 : length(flights)
end % for  dd = 1 : length(day_files)
clearvars -except *_dir user_email day_files
cd(global_dir)
%%
