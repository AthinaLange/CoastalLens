function [TimeZone] = define_timezone
% TIMEZONE Define timezone
%     [TimeZone] = define_timezone User prompted timezone selection
%
%     TimeZone (string): user selected timezone

% Can be used in datetime construction.

cont_areas = [{'Africa'}, {'America'}, {'Antarctica'}, {'Arctic'}, {'Asia'}, {'Atlantic'}, {'Australia'}, {'Europe'}, {'Indian'}, {'Pacific'}, {'All'}];
[ind_area,~] = listdlg('ListString', cont_areas, 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Which geographic region are you in?'});

geo_areas = timezones(char(cont_areas(ind_area)));
[ind_area,~] = listdlg('ListString', geo_areas.Name, 'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Which geographic region are you in?'});
TimeZone = char(geo_areas.Name(ind_area));
end