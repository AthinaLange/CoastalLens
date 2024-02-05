function [timezone] = select_timezone
%   select_timezone returns timezone from user selection (based on MATLAB timezones)
%% Syntax
% [timezone] = select_timezone
%
%% Description
%   Args:
%
%   Returns:
%           timezone (string): user-selected Internet Assigned Numbers Authority (IANA) time zone accepted by the datetime function
%
%
% Can be used to define the timezone of a MATLAB datetime variable: datetime_variabel.TimeZone = timezone.
% See <a href="matlab:web('https://www.mathworks.com/help/matlab/ref/timezones.html')"> MATLAB timezones</a> for list of
% timezones.
%
%
%% Example 1
% [timezone] = select_timezone;
% datetime('now', 'TimeZone', timezone)
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;

%% Select timezone

cont_areas = [{'Africa'}, {'America'}, {'Antarctica'}, {'Arctic'}, {'Asia'}, {'Atlantic'}, {'Australia'}, {'Europe'}, {'Indian'}, {'Pacific'}, {'All'}];
[ind_area,~] = listdlg('ListString', cont_areas, 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Which geographic region are you in?'});

geo_areas = timezones(char(cont_areas(ind_area)));
[ind_area,~] = listdlg('ListString', geo_areas.Name, 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Which geographic region are you in?'});
timezone = char(geo_areas.Name(ind_area));
end