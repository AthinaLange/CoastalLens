% cBathyTide 0
function tide = cBathyTideneutral(epoch)

% function tide = cBathyTide( stationStr, epoch )
%
%  this is a prototype function to demonstrate what info needs to be
%  found to deal with tides. It's called based on the tide function
%  specified in the settings file. 
%
%  if it doesn't work for your system, you need to create one.
%
%  intermediate function to get predicted or measured tides for station
%
%  returns a struct tide with fields e (epoch of tide), zt (tide value),
%  and source ('p' for predicted, 'm' for measured, and '' for none.) 
%  zt will be NaN if there is no value (and source should be '');

% default return
% tide.e = 0;
% tide.zt = NaN;
% tide.source = '';
% 
% station = '9413616'; % Moss Landing
%    
% tide.e = str2num(epoch);
% tide.source = 'm';
% t = datetime(epoch2Matlab(str2num(epoch)), 'ConvertFrom', 'datenum');
% [~,~,verified,~,~] = getNOAAtide(t(1), t(1)+minutes(17),station)
tide.zt = 0%nanmean(verified);
end