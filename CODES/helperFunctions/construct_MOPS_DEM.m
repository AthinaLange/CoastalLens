%% construct DEM from MOPS data
% requires x, y and z coordinates as DEM.x, DEM.y, DEM.z

%% Torrey - 582
% alongshore = [-100:100:700]
% 
% for ii = 1:length(files)
%     load(files(ii).name, 'SM')
%     MOP(ii).MOP = alongshore(ii)/100 + 582;
%     MOP(ii).y = alongshore(ii);
%     for mm = 1:length(SM)
%         MOP(ii).time(mm,:) = datetime(SM(mm).Datenum, 'ConvertFrom', 'datenum');
%         MOP(ii).Source{mm} = SM(mm).Source;
%         MOP(ii).x(mm,:) = SM(mm).X1D;
%         MOP(ii).z(mm,:) = SM(mm).Z1Dmedian;
% 
%     end
% end
% save('Torrey_MOPs', 'MOP')

%%
date_input = inputdlg({'Date for DEM (YYYYMMDD)'});
date = datetime(date_input, 'InputFormat', 'uuuuMMdd')


load(fullfile(data_dir, 'Bathy', 'Torrey_MOPS.mat'))

for ii = 1:length(MOP)
    DEM(ii).y = MOP(ii).y;
    id = find(min(abs(MOP(ii).time - date)) == abs(MOP(ii).time - date));
   
    if length(id) > 1 && contains(MOP(ii).Source(id), 'Gps')
        id = id(contains(MOP(ii).Source(id), 'Gps'));
    else
        id = id(1);
    end

    DEM(ii).time = MOP(ii).time(id);
    DEM(ii).x = MOP(ii).x(id,:);
    DEM(ii).z= MOP(ii).z(id,:);
end
save([date_input{:} '_DEM.mat'], 'DEM')