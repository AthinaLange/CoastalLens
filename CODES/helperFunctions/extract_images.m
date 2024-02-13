function extract_images(data_files, varargin)
%   extract_images extracts images from given data files at specified frame rate
%% Syntax
% extract_images(data_files)
% extract_images(data_files, frameRate = 2)
%
%% Description
%   Args:
%           data_files (structure) : Data (video) files to extract images - requires data_files.folder and data_files.name
%           varargin :
%                       frameRate (double): Extraction frame rate in Hz (default: 2Hz)
%
%   Returns:
%
%
%   REQUIRES: ffmpeg installation (https://ffmpeg.org/)
%
%% Example 1
%
% data_files = dir('DATA/20211215_Torrey/Flight_04');
% extract_images(data_files, frameRate = 1)
% combine_images(data_files, imageDirectory = 'DATA/20211215_Torrey/Flight_04/images_1Hz')
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Nov 2023;

%% Options
options.frameRate = 2; % frameRate in Hz (default = 2Hz)
options = parseOptions( options , varargin );

assert(isa(data_files, 'struct'), 'Error (extract_images): data_files must be a structure.')
assert((isfield(data_files, 'folder') && isfield(data_files, 'name')), 'Error (extract_images): data_files must have fields .folder and .name.')
assert(isa(options.frameRate, 'double'), 'Error (extract_images): frameRate must be a double.')

%% Extract frames at specified frameRate (using ffmpeg)
for dd = 1:length(data_files)
    cd(data_files(dd).folder)
    folder_name = split(data_files(dd).name, '.'); folder_name = string(folder_name{1});
    mkdir(fullfile(data_files(dd).folder, folder_name))
    system(['ffmpeg -i ' char(string(data_files(dd).name)) ' -qscale:v 2 -r ' char(string(options.frameRate)) ' ' fullfile(data_files(dd).folder, char(folder_name), 'Frame_%05d.jpg')])
end % for dd = 1:length(data_files)

end