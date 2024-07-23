function [C] = get_metadata(odir, oname, varargin)
%   get_metadata returns table C and saves .csv of metadata from images and videos.
%% Syntax
%           [C] = get_metadata('./DATA/20211215_Torrey/Flight_04/', '20211215_Torrey')
%           [C] = get_metadata('./DATA/20211215_Torrey/Flight_04/', '20211215_Torrey', file_prefix = 'DJI')
%           [C] = get_metadata('./DATA/20211215_Torrey/Flight_04/', '20211215_Torrey', save_dir = './DATA/20240101_SIO/01/Processed_data/')
%
%% Description
%   Args:
%           odir (string) : directory path (full or relative) where images/videos are located
%           oname (string) : file name for metadata csv
%           varargin :
%                       file_prefix (string) : prefix of files to extract metadata from,
%                                                      e.g. 'DJI' for 'DJI_0004.MOV'.
%                                                      Will get metadata for all files in folder and
%                                                      subfolders if this is empty.
%                       save_dir (string) : save directory, if not the same as odir
%
%   Returns:
%       C (table) : Table of image/video metadata
%
%
%   REQUIRES: exiftool installation (https://exiftool.org/)
%
%% Example 1
%  [C] = get_metadata('./DATA/20211215_Torrey/Flight_04/', '20211215_Torrey', file_prefix = 'DJI')
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Nov 2023;

%% Data

assert(isa(odir, 'char'),'Error (get_metadata): odir must be a string to a directory path.');
assert(isfolder(odir),'Error (get_metadata): odir must be the path to the directory folder.');
assert(isa(oname, 'char'),'Error (get_metadata): oname must be a string for csv name.');

options.file_prefix = ''; % Filename extension, e.g. 'DJI' for 'DJI_0004.MOV'.
options.save_dir = odir;
options = parseOptions(options , varargin);

assert(isa(options.file_prefix, 'char'),'Error (get_metadata): file_prefix must be a string.');
assert(isa(options.save_dir, 'char'),'Error (get_metadata): save_dir must be a string to the saving folder path.');
assert(isfolder(options.save_dir),'Error (get_metadata): save_dir must be the path to the saving folder.');

%% Use exiftool to pull metadata
if ismac
    system(sprintf('/usr/local/bin/exiftool -filename -CreateDate -Duration -CameraPitch -CameraYaw -CameraRoll -AbsoluteAltitude -RelativeAltitude -GPSLatitude -GPSLongitude -csv -c "%%.20f" %s/%s* > %s', odir, options.file_prefix, fullfile(options.save_dir, [oname '.csv'])));
else
    system(sprintf('exiftool -filename -CreateDate -Duration -CameraPitch -CameraYaw -CameraRoll -AbsoluteAltitude -RelativeAltitude -GPSLatitude -GPSLongitude -csv -c "%%.20f" %s/%s* > %s', odir, options.file_prefix, fullfile(options.save_dir, [oname '.csv'])));
end

C = readtable(fullfile(options.save_dir, [oname '.csv']));
end