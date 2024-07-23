%% save_timestacks_ARGUS
% save_timestacks_ARGUS saves timestack images from Products as png's in Rectified_images folder.
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
%                       localX (double) : [y_length x x_length] x coordinates in locally-defined coordinate system (+x is offshore, m)
%                       localY (double) : [y_length x x_length] y coordinates in locally-defined coordinate system (+y is right of origin, m)
%                       localZ (double) : [y_length x x_length] z coordinates in locally-defined coordinate system
%                       Eastings (double) : [y x x] Eastings coordinates (m)
%                       Northings (double) : [y x x] Northings coordinates (m)
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
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
% Jul 2024;

%% Data

if ~exist('global_dir', 'var')
    disp('Please select the global directory.')
    global_dir = uigetdir('.', 'CoastalLens_ARGUS');
    cd(global_dir)
end
if ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
    disp('Choose DATA folder.')
    data_dir = uigetdir('.', 'DATA Folder');

    % Load in all days that need to be processed.
    day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
    day_files(contains({day_files.name}, 'GCP'))=[]; day_files(contains({day_files.name}, 'Make_products'))=[];
    day_files(contains({day_files.name}, 'Processed_data'))=[];day_files(contains({day_files.name}, 'Products'))=[];
    
    processed_files = dir(fullfile(data_dir, 'Processed_data')); processed_files([processed_files.isdir] == 1)=[];
    processed_files(~contains({processed_files.name}, 'Products'))=[];
    % if file already processed - don't reprocess
    if ~isempty(processed_files)
        for ii = length(day_files):-1:1
            if contains([processed_files.name], day_files(ii).name)
                day_files(ii) = [];
            end
        end
    end
end

%% save products
disp('How many cameras are you processing?')
cam_num = str2double(string(inputdlg('How many cameras?')));

close all
odir = fullfile(data_dir, 'Processed_data');
        
for  dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files cam_num odir
    cd(odir)
    
    for cc = 1:cam_num
        oname = strcat('ARGUS2_Cam', string(cc),'_', day_files(dd).name);
        disp(oname)
        save_dir = fullfile(odir, 'Rectified_images');
         if ~exist(save_dir, 'dir')
            mkdir(save_dir)
         end % if ~exist(save_dir, 'dir')
         load(fullfile(data_dir, 'Processed_data', strcat(oname, '_Products')), 'Products')
         % only want to save x_transects and y_transects
         Products(contains({Products.type}, 'Grid'))=[];
         save_rectified_image(oname, save_dir, Products)
         if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Save timestacks DONE'])
        end % if exist('user_email', 'var')
    end % for cc = 1:cam_num
end % for  dd = 1 : length(day_files)
clearvars -except *_dir user_email day_files
cd(global_dir)
%%
