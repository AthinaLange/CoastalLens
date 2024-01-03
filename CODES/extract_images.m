function extract_images(data_files, varargin)
%% extract_images
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
% check if user_email an input variable
if length(nargin) == 1
    user_email = varargin{1};
end


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

        % repeat for each extracted frame rate
        for hh = 1 : length(extract_Hz)
            if ~exist(sprintf('images_%iHz', extract_Hz(hh)), 'dir')
                mkdir(sprintf('images_%iHz', extract_Hz(hh)))

                imageDirectory = sprintf('images_%iHz', extract_Hz(hh));
                load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'jpg_id', 'mov_id', 'C')

                % repeat for each video
                % extract images at extract_Hz rate wtih ffmpeg
                for ii = mov_id
                    mkdir(fullfile(imageDirectory, char(string(ii))))
                    system(['ffmpeg -i ' char(string(C.FileName(ii))) ' -qscale:v 2 -r ' char(string(extract_Hz(hh))) ' ' fullfile(imageDirectory, char(string(ii)), 'Frame_%05d.jpg')])
                end

                % Combine images and rename into sequential
                for ii = mov_id
                    L = imageDatastore(imageDirectory);
                    Lfull = length(L.Files);
                    L = imageDatastore(fullfile(imageDirectory, char(string(ii))));

                    if ii == 1
                        movefile(fullfile(imageDirectory, char(string(ii)), 'Frame_*'), imageDirectory)
                    else
                        % rename files to be sequential based on total image frames
                        for ll = 1: length(L)
                            if ll < 10
                                id = ['0000' char(string(ll))];
                            elseif ll < 100
                                id = ['000' char(string(ll))];
                            elseif ll < 1000
                                id = ['00' char(string(ll))];
                            elseif ll < 10000
                                id = ['0' char(string(ll))];
                            else
                                id = [char(string(ll))];
                            end

                             if ll+Lfull < 10
                                id_full = ['0000' char(string(ll+Lfull))];
                            elseif ll+Lfull < 100
                                id_full = ['000' char(string(ll+Lfull))];
                            elseif ll+Lfull < 1000
                                id_full = ['00' char(string(ll+Lfull))];
                            elseif ll+Lfull < 10000
                                id_full = ['0' char(string(ll+Lfull))];
                            else
                                id_full = [char(string(ll+Lfull))];
                            end

                            movefile(fullfile(imageDirectory, char(string(ii)), ['Frame_' id '.jpg']), fullfile(imageDirectory, ['Frame_' id_full '.jpg']))
                        end
                    end  % if ii == 1
                end % for ii = 1:length(mov_id)

                % remove placeholder folders
                for ii = mov_id; rmdir(fullfile(imageDirectory, char(string(ii))), 's'); end

                % replacing 1st image with image extracted as initial frame for gcp and scp accuracy
                if ispc
                    system(['cp Processed_data\Initial_frame.jpg ' imageDirectory '\Frame_00001.jpg'])
                else
                    system(['cp Processed_data/Initial_frame.jpg ' imageDirectory '/Frame_00001.jpg'])
                end
            end % if ~exist(sprintf('images_%iHz', extract_Hz(hh)), 'dir')
        end % for hh = 1:length(extract_Hz)

        if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Image Extraction Done'])
        end
    end % for ff = 1:length(flights)
end % for dd = 1:length(data_files)