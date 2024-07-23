%% Pixel resolution
% Using the CIRN Station Design toolbox
%
%% Input
%   file naming convention - YYYYMMDD_location_hover_MOP
%       if not, then need to change use of aa in 'Get stats from metadata'
%   Update camera specs based on given camera
%   Have metadata on Altitude, Yaw, Pitch and Roll of camera
%
%
%% Installation
%
%   requires toolbox from CIRN
%       <https://github.com/Coastal-Imaging-Research-Network/Support-Routines>
%       <https://github.com/Coastal-Imaging-Research-Network/Station-Design-Toolbox>
%
%% Output
%   cutoff (structure)
%       date
%       hover #
%       mopgrid - x-location
%       crest_track - for every MOP point, what is the offshore distance
%       cutoff based on pixel = 2*gridding for crest-tracking (0.2m)
%       cbathy - for every MOP point, what is the offshore distance
%       cutoff based on pixel = 2*gridding for cbathy (2m)
%
%
%%
function [stats] = pixel_res(R, C)
%% Camera Specs:

nameCam = 'THEIA';  % String that represents the name of the camera
%   E.g. 'Flir Boson 640',...

numCam = 1; % Number of cameras to be used.

focalLength = mean(R.intrinsics.FocalLength);  % Focal length of the camera lens in mm.

NU = R.intrinsics.ImageSize(2);   % Width of the chip (A.K.A. sensor) in pixels
NV = R.intrinsics.ImageSize(1);   % Height of the chip in pixels

hfov = 76.25;
vfov = 47.64;

roll=0;
txyz=[0,0,0];
%% Get stats from metadata

stats.elevation = R.worldPose.Translation(3);
stats.heading = 360 + C.CameraYaw(end);
stats.roll = C.CameraRoll(end);
stats.tilt = 90 + C.CameraPitch(end);

%% Compute range

[XYZVertices, res, dcRange, daRange, dcProj, daProj] = computeFootprint(hfov, vfov, stats.heading, stats.tilt, stats.roll, NU, NV, [0,0, stats.elevation], txyz);
[x,y]=meshgrid(res{1,1}.x, res{1,1}.y);
stats.res.x=x;
stats.res.y=y;
stats.res.daRange = daRange;
stats.res.dcRange = dcRange;


% find range values for crest-tracking and cBathy
% stats.res.range_ct = NaN(length(stats.res.x), length(stats.res.x));
% stats.res.range_ct(find(stats.res.daRange < 3*dx & stats.res.dcRange < 3*dx)) = 1;
% 
% stats.res.range_cb = NaN(length(stats.res.x), length(stats.res.x));
% stats.res.range_cb(find(stats.res.daRange < 3*5 & stats.res.dcRange < 3*5)) = 1;


%     mopgrid = [-300:100:300];
%     idy_ct = NaN(length(stats), length(mopgrid));
%     idy_cb = NaN(length(stats), length(mopgrid));
%     for ff = 1:length(stats)
%             for mm = 1:length(mopgrid)
%                 mop=mopgrid(mm);
%                 idx = find(stats.res.x(1,:)==mop);
%                 idys = stats.res.y(find(stats.res.range_ct(idx,:)==1),idx);
%                 if ~isempty(idys)
%                     idy_ct(ff,mm)=min(idys);
%                 end
%                 idys = stats.res.y(find(stats.res.range_cb(idx,:)==1),idx);
%                 if ~isempty(idys)
%                     idy_cb(ff,mm)=min(idys);
%                 end
%             end
%     end
%
%     %% Put into cutoff variable
%     clear cutoff
% cutoff(jj).crest_track = squeeze(idy_ct(ff,:));
%             cutoff(jj).cbathy = squeeze(idy_cb(ff,:));
%             cutoff(jj).stats = stats;
end