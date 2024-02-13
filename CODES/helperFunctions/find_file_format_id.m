function [id] = find_file_format_id(C, varargin)
% find_file_format_id returns id of files (listed in table C) matching specified file format.
%% Syntax
%           [id] = find_file_format_id(C, file_format = 'JPG')
%           [id] = find_file_format_id(C, file_format = {'MOV', 'MP4'})
%
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
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Nov 2023;

%% Options
options.file_format = {'JPG'}; % file extension to search for
options = parseOptions(options , varargin);

assert(isa(C, 'table'), 'Error (find_file_format_id): C must be a table.')
assert(isa(options.file_format, 'cell'), 'Error (find_file_format_id): file_format must be a string.')
%% Pull index that matches file format
format long
% get indices of images and videos to extract from
form = char(C.FileName);
for ii = 1:size(form,1)
    aa=split(string(form(ii,:)), '.');
    ending(ii,:) = aa(end);
end % for ii = 1:size(form,1)
ending = strtrim(ending);

id = rem(find(ending == string(options.file_format)), length(ending));
id(id == 0) = length(ending);
id = sort(id);

end