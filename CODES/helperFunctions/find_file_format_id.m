function [id] = find_file_format_id(C, varargin)
%   Returns table of metadata from images and videos.
%
%% Syntax
%           [id] = find_file_format_id(C, file_format = 'JPG')
%           [id] = find_file_format_id(C, file_format = {'MOV', 'MP4'})
%% Description
%   Args:
%           C (table) : Table of image/video metadata
%           varargin :
%                       file_format (string, cell array of strings) : file extensions to search for 
%                                                                                       (default: JPG)
%
%   Returns:
%           id (array) : list of ids that match file_format
%
%% Example 1
%
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; Last revision: XXX

%% Options
options.file_format = {'JPG'}; % file extension to search for
options = parseOptions(options , varargin);

%% Pull index that matches file format
format long
% get indices of images and videos to extract from
form = char(C.FileName);
for ii = 1:size(form,1)
    aa=split(string(form(ii,:)), '.');
    ending(ii,:) = aa(end);
end
ending = strtrim(ending);

id = rem(find(ending == string(options.file_format)), length(ending));
id(id == 0) = length(ending);
id = sort(id);

end