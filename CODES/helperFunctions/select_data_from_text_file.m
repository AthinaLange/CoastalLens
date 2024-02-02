function [selected_data] = select_data_from_text_file
%   Choose data from text file
%% Syntax
%          [selected_data] = select_data_from_text_file
%
%% Description
%   Args:
%
%   Returns:
%         selected_data (array) : array of selected data from text file
%
% Data must be comma-separated list in .txt file
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Load file and select data points
[temp_file, temp_file_path] = uigetfile({'*.txt'}, 'Data File');
data = load(fullfile(temp_file_path, temp_file)); clear temp_file_path

[selected_ids,~] = listdlg('ListString', arrayfun(@num2str, [1:size(data,1)], 'UniformOutput', false), ...
    'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Select data to use', '(command + for multiple)'});
selected_data = data(selected_ids, :);