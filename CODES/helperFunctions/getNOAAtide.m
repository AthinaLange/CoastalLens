function [t_verified,t_predicted,verified,predicted,tideInfo] = getNOAAtide(begin_date,end_date,station,datum)
% get tides from NOAA buoy
% [t,verified,predicted,tideInfo]= getNOAAtide(20140204,20140206)
% Scripps Pier station is 9410230
% FROM JULIA FIEDLER
disp('hi')
if nargin<4
    datum = 'NAVD';
end
% station = '9410230';
time_zone = 'GMT';%'LST'
units = 'metric';

tideInfo = struct('datum',datum,'station',station,...
    'time_zone',time_zone,'units',units,...
    'begin_date',begin_date,'end_date',end_date);

% check to see what input the date is in
if isdatetime(begin_date)
    begin_date = datestr(begin_date,'yyyymmdd HH:MM');
    end_date = datestr(end_date,'yyyymmdd HH:MM');
    ta = datenum(begin_date,'yyyymmdd HH:MM');
    tb = datenum(end_date,'yyyymmdd HH:MM');
elseif ischar(begin_date)
    begin_date = datetime(begin_date,'InputFormat','yyyyMMdd');
    end_date = datetime(end_date,'InputFormat','yyyyMMdd');
    begin_date = datestr(begin_date,'yyyymmdd HH:MM');
    end_date = datestr(end_date,'yyyymmdd HH:MM');
    % check to see length of timeseries
    ta = datenum(begin_date,'yyyymmdd HH:MM');
    tb = datenum(end_date,'yyyymmdd HH:MM');
elseif isnumeric(begin_date)
    ta = begin_date;
    tb = end_date;
    begin_date = datestr(begin_date,'yyyymmdd HH:MM');
    end_date = datestr(end_date,'yyyymmdd HH:MM');
end
disp(begin_date)
disp(end_date)
% preassign variables
t_verified = [];
verified = [];
t_predicted = [];
predicted = [];



if tb-ta < 30
    %     disp('hi')
    product = 'predictions';
    S = getSdata(product,begin_date,end_date,datum,station,time_zone,units);
    
    t_predicted = S(:,1);
    t_predicted = cellfun(@datenum,t_predicted);
    
    predicted = cell2mat(S(:,2));
    
    product = 'water_level';
    %     product = 'one_minute_water_level';
    
    
    S = getSdata(product,begin_date,end_date,datum,station,time_zone,units);
    
    t_verified = S(:,1);
    t_verified = cellfun(@datenum,t_verified);
    verified = cell2mat(S(:,2));
end

if tb-ta>=30
    begin_datetemp = begin_date;
    end_datetemp = ta+29;
    while end_datetemp < (tb +29) % if this is true we will have to download in chunks
        disp('hi')
        disp('grabbing data in chunks')
        disp(['grabbing data for ',begin_datetemp,' to ',datestr(end_datetemp,'yyyymmdd')])
        
        end_datetemp = datestr(end_datetemp,'yyyymmdd');
        
        product = 'predictions';
        S = getSdata(product,begin_datetemp,end_datetemp,datum,station,time_zone,units);
        
        if isempty(S)
            !
        end
        
        ti = S(:,1);
        ti = cellfun(@datenum,ti);
        t_predicted = [t_predicted; ti];
        
        pred = cell2mat(S(:,2));
        predicted = [predicted; pred];
        
        product = 'water_level'; %one_minute_water_level
        S = getSdata(product,begin_datetemp,end_datetemp,datum,station,time_zone,units);
        
        ti = S(:,1);
        ti = cellfun(@datenum,ti);
        t_verified = [t_verified; ti];
        ver = cell2mat(S(:,2));
        verified = [verified; ver];
        
        begin_datetemp = datenum(begin_datetemp,'yyyymmdd') + 30;
        begin_datetemp = datestr(begin_datetemp,'yyyymmdd');
        end_datetemp = datenum(begin_datetemp,'yyyymmdd')+29;
        
    end
end

    function S = getSdata(product,begin_date,end_date,datum,station,time_zone,units)
        api = 'https://tidesandcurrents.noaa.gov/api/datagetter?';
        ss = strcat('product=',product,'&application=NOS.COOPS.TAC.WL&begin_date=',...
            begin_date,'&end_date=',end_date,'&datum=',datum,'&station=',station,...
            '&time_zone=',time_zone,'&units=',units,'&format=csv');
        url = [api ss];
        options = weboptions('Timeout',5);
        S = webread(url,options);
        S = table2cell(S);
    end
end

