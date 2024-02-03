function combine_images(data_files, varargin)
%   Combine image sequence from multiple folders
%% Syntax
% combine_images(data_files)
% combine_images(data_files, imageDirectory = pwd)
%
%% Description
%   Args:
%           data_files (structure) : Data files to extract images - requires data_files.folder and data_files.name
%           varargin :
%                       imageDirectory (string): Image directory where files should be saved to (default : pwd)
%
%   Returns:
%
%% Example 1
%
% data_files = dir('DATA/20211215_Torrey/01');
% extract_images(data_files, frameRate = 2)
% combine_images(data_files, imageDirectory = 'images_2Hz')
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Options
options.imageDirectory = fullfile(data_files(1).folder); % imageDirectory where files should be saved
options = parseOptions( options , varargin );

assert(isa(data_files, 'struct'), 'Error (combine_images): data_files must be a structure.')
assert((isfield(data_files, 'folder') && isfield(data_files, 'name')), 'Error (combine_images): data_files must have fields .folder and .name.')
assert(isa(options.imageDirectory, 'char'), 'Error (combine_images): imageDirectory must be a string.')
assert(isfolder(options.imageDirectory),'Error (combine_images): imageDirectory must be the path to a folder.');

%% Combine images
for dd = 1:length(data_files)
    folder_name = split(data_files(dd).name, '.'); folder_name = string(folder_name{1});
    folder_name = fullfile(data_files(dd).folder, char(folder_name));
    if dd == 1
        movefile(fullfile(folder_name, 'Frame_*'), options.imageDirectory)
    else
        L = imageDatastore(options.imageDirectory);
        Lfull = length(L.Files);

        L = imageDatastore(folder_name);

        % rename files to be sequential based on total image frames
        for ll = 1: length(L.Files)
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

            movefile(fullfile(folder_name, ['Frame_' id '.jpg']), fullfile(options.imageDirectory, ['Frame_' id_full '.jpg']))
        end % for ll = 1:length(L)
    end  % if dd == 1
    % remove placeholder folders
    rmdir(folder_name, 's')
end % for dd = 1:length(data_files)

end