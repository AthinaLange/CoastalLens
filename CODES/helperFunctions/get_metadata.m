function [C] = get_metadata(odir, oname, varargin)
%   Returns table and saves .csv of metadata from images and videos.
%% Syntax
%           [C] = get_metadata('./DATA/20240101_SIO/01/', '20240101_SIO')
%           [C] = get_metadata('./DATA/20240101_SIO/01/', '20240101_SIO', file_prefix = 'DJI')
%           [C] = get_metadata('./DATA/20240101_SIO/01/', '20240101_SIO', save_dir = './DATA/20240101_SIO/01/Processed_data/')
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
% Extract images:
% 
% data_files = dir('DATA/20211026_Torrey/01');
% extract_images(data_files, frameRate = 2)
%
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; Last revision: XXX

%% Data

assert(isa(odir, 'char'),'Error: odir must be a string to a directory path.');
assert(isfolder(odir),'Error: odir must be the path to the directory folder.');
assert(isa(oname, 'char'),'Error: oname must be a string for csv name.');

options.file_prefix = ''; % Filename extension, e.g. 'DJI' for 'DJI_0004.MOV'.
options.save_dir = odir;
options = parseOptions(options , varargin);

assert(isa(options.file_prefix, 'char'),'Error: file_prefix must be a string.');
assert(isa(options.save_dir, 'char'),'Error: save_dir must be a string to the saving folder path.');
assert(isfolder(options.save_dir),'Error: save_dir must be the path to the saving folder.');

%% Use exiftool to pull metadata
system(sprintf('/usr/local/bin/exiftool -filename -CreateDate -Duration -CameraPitch -CameraYaw -CameraRoll -AbsoluteAltitude -RelativeAltitude -GPSLatitude -GPSLongitude -csv -c "%%.20f" %s/%s* > %s', odir, options.file_prefix, fullfile(options.save_dir, [oname '.csv'])));

C = readtable(fullfile(options.save_dir, [oname '.csv']));
