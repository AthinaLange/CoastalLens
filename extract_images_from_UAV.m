% extract_images_from_UAV
% This script extracts images from video files at specified frame rates for every day and flight.
% 
% Requires: 
%       data_files - structure (dir) with days to process.
%       global_dir - global directory string
%
%   For each extraction frame rate:
%           - make Hz directory for images (e.g. images_10Hz/)
%           - for every movie to be extracted: extract images from video at extraction frame rate using ffmpeg (into seperate folder intially)
%           - move images from movie folders into group folder and rename sequentially
%   Send email that image extraction complete
%
% REQUIRES: ffmpeg installation (https://ffmpeg.org/)
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%% Data check
if exist('data_files','var') && isstruct(data_files) && isfield(data_files, 'folder') && isfield(data_files, 'name')
    %
else  % Load in all days that need to be processed.
    data_dir = uigetdir('.', 'DATA Folder');
    disp('Please select the days to process:')
    data_files = dir(data_dir); data_files([data_files.isdir]==0)=[]; data_files(contains({data_files.name}, '.'))=[];
    [ind_datafiles,~] = listdlg('ListString',{data_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'});
    data_files = data_files(ind_datafiles);
end
if exist('global_dir', 'var') && isstring(global_dir)
    %
else % select global directory
    disp('Please select the global directory.')
    global_dir = uigetdir('.', 'UAV Rectification');
    cd(global_dir)
end

%% Extract images from UAV video
% repeat for each day
for dd = length(data_files)
    clearvars -except dd *_dir user_email data_files
    cd(fullfile(data_files(dd).folder, data_files(dd).name))

    load(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'), 'extract_Hz', 'flights')

    % repeat for each flight
    for ff = 1: length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [data_files(dd).name '_' flights(ff).name];
        cd(odir)

        load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'jpg_id', 'mov_id', 'C')

        video_files = dir(fullfile(data_files(dd).folder, data_files(dd).name, flights(ff).name));
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
                    system(['cp Processed_data\Initial_frame.jpg ' imageDirectory '\Frame_00001.jpg'])
                else
                    system(['cp Processed_data/Initial_frame.jpg ' imageDirectory '/Frame_00001.jpg'])
                end
            end % if ~exist(sprintf('images_%iHz', extract_Hz(hh)), 'dir')
        end % for hh = 1:length(extract_Hz)

        if exist('options.user_email', 'var')
            sendmail(options.user_email, [oname '- Image Extraction Done'])
        end
    end % for ff = 1:length(flights)
end % for dd = 1:length(data_files)
clearvars -except *_dir user_email data_files
cd(global_dir)
