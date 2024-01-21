% extract_images_from_UAV

% This script extracts images from video files at specified frame rates.
% Repeat for each day + flight
%
%   For each extraction frame rate:
%           - make Hz directory for images
%           - for every movie to be extracted: extract images from video at extraction frame rate using ffmpeg (into seperate folder intially)
%           - move images from movie folders into group folder and rename sequentially
%
%  Send email that image extraction complete
%
% REQUIRES: ffmpeg installation (https://ffmpeg.org/)
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%%
% include data check
% repeat for each day
for dd = 1:length(day_files)
    clearvars -except dd *_dir user_email day_files
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'extract_Hz', 'flights')

    % repeat for each flight
    for ff = 1: length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        cd(odir)

        load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'jpg_id', 'mov_id', 'C')

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
end % for dd = 1:length(day_files)
