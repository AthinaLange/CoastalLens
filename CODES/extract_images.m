function extract_images(data_files, varargin)
% EXTRACT_IMAGES  Extract images from given data files at specified frame rate
%     extract_images(data_files) Structure of data files - requires data_files.folder and data_files.name
%     extract_images(data_files, frameRate = 2) Extract frames at 2Hz
%
%
% This script extracts images from video files at specified frame rates.
%
% REQUIRES: ffmpeg installation (https://ffmpeg.org/)
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%%
options.frameRate = 2; % frameRate in Hz (default = 2Hz)

options = parseOptions( options , varargin );

%% Extract frames at specified frameRate
for dd = 1:length(data_files) % 
    cd(data_files(dd).folder)
    folder_name = split(data_files(dd).name, '.'); folder_name = string(folder_name{1});
    mkdir(fullfile(data_files(dd).folder, folder_name))
    system(['ffmpeg -i ' char(string(data_files(dd).name)) ' -qscale:v 2 -r ' char(string(options.frameRate)) ' ' fullfile(data_files(dd).folder, char(folder_name), 'Frame_%05d.jpg')])
end

end

