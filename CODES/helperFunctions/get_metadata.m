function [C, jpg_id, mov_id] = get_metadata(odir, oname, drone_file_name)

system(sprintf('/usr/local/bin/exiftool -filename -CreateDate -Duration -CameraPitch -CameraYaw -CameraRoll -AbsoluteAltitude -RelativeAltitude -GPSLatitude -GPSLongitude -csv -c "%%.20f" %s/%s_0* > %s', odir, drone_file_name, fullfile(odir, 'Processed_data', [oname '.csv'])));

C = readtable(fullfile(odir, 'Processed_data', [oname '.csv']));

format long
% get indices of images and videos to extract from
form = char(C.FileName);
form = string(form(:,end-2:end));
mov_id = find(form == 'MOV' | form == 'MP4');
jpg_id = find(form == 'JPG');

% remove any weird videos
% i_temp = find(isnan(C.Duration(mov_id))); mov_id(i_temp)=[];

% if image taken at beginning & end of flight - use beginning image
if length(jpg_id) > 1; jpg_id = jpg_id(1); end
% if no image taken, use mov_id
if isempty(jpg_id); jpg_id = mov_id(1); end

% CONFIRM VIDEOS TO PROCESS
[id, ~] = listdlg('ListString', append(string(C.FileName(mov_id)), ' - ',  string(C.Duration(mov_id))), 'SelectionMode','multiple', 'InitialValue',[1:length(mov_id)], 'PromptString', {'What movies do you want' 'to use? (command + for multiple)'});
mov_id = mov_id(id);

end