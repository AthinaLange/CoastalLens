function [DEM] = define_DEM
%% define_DEM
% define_DEM generates DEM based off of user input MOP numbers and dates
%% Description
%
%   Inputs:
%
%   Returns:
%           DEM (structure) : Digital Elevation Map Data
%                       time (datetime) : date of jumbo survey used
%                       type (cell array) : Survey type for each transect
%                       MOP (cell array) : Mop number of each x transect
%                       X (array): [mop_length x cross-shore length] - Eastings
%                       Y (array): [mop_length x cross-shore length] - Northings
%                       Z (array): [mop_length x cross-shore length] - Elevation (NAVD88m)
%                       min_tide (double) : minimum tide that day (NAVD88m) - limit of subaerial survey when a full profile was taken
%
%
%% Function Dependenies
% MOPS_toolbox/GetAllNearestPointsProfiles
% MOPS_toolbox/GetTransectLines
% MOPS_toolbox/MopTableUTM
% MOPS_toolbox/EqualSpacedPoints
% getNOAAtide
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jul 2024;

clear all
%% =============== Choose MOP folder.  ===================================
% Load which data folders are to be processed
if ismac || isunix
    disp('Choose MOP folder - location of MOP SA files')
end
mop_dir = uigetdir('.', 'MOP Folder - location of MOP SA files');
addpath(genpath(mop_dir))
MOP_files = dir(mop_dir); MOP_files([MOP_files.isdir]==1)=[];
MOP_files(~contains({MOP_files.name}, 'SA.mat'))=[];

%% =============== Define DEM grid  ======================================
load(fullfile(mop_dir, 'MopTableUTM.mat'), 'Mop')
Mopnum = double(string(inputdlg({'MOP origin number'})));
origin_grid = [Mop.BackLat(Mopnum) Mop.BackLon(Mopnum) Mop.Normal(Mopnum)];

Product.lat = origin_grid(1);
Product.lon = origin_grid(2);
Product.angle = origin_grid(3);

info = double(string(inputdlg({'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin, + if offshore)', ...
    'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
    'dx (Cross-shore Resolution m)', 'dy (Along-shore Resolution m)'}, 'Grid Coordinates')));

% check that there's a value in all the required fields
if find(isnan(info)) ~= 6
    disp('Please fill out all boxes (except z elevation if necessary)')
    info = double(string(inputdlg({'Offshore cross-shore extent (m from Origin, + if offshore)', 'Onshore cross-shore extent (m from Origin, + if offshore)', ...
        'Southern Alongshore extent (+m from Origin)', 'Northern Alongshore extent (+m from Origin)',...
        'dx (Cross-shore Resolution m)', 'dy (Along-shore Resolution m)'}, 'Grid Coordinates')));
end % if find(isnan(info)) ~= 7

Product.xlim = [info(1) info(2)];
if origin_grid(3) < 180 % East Coast
    Product.ylim = [-info(4) info(3)]; % -north +south
elseif origin_grid(3) > 180 % West Coast
    Product.ylim = [-info(3) info(4)]; % -south +north
end % if origin_grid(3) < 180 % East Coast
Product.dx = abs(info(5));
Product.dy = abs(info(6));

[Eastings, Northings] = make_grid(Product);
%% =============== Only keep relevant MOP files  ============================
mop_numbers = Mopnum + Product.ylim/100; mop_numbers = [floor(mop_numbers(1)):1:ceil(mop_numbers(end))];
if all(mop_numbers < 1000)
    MOP_files(~contains({MOP_files.name}, strcat('00', string(mop_numbers)))) = [];
elseif all(mop_numbers > 1000)
    MOP_files(~contains({MOP_files.name}, strcat('0', string(mop_numbers)))) = [];
end
%% =============== Pull all survey dates -> can be changed ====================
load(fullfile(MOP_files(contains({MOP_files.name}, string(Mopnum))).folder, MOP_files(contains({MOP_files.name}, string(Mopnum))).name), 'SA');
survey_dates = datetime([SA.Datenum], 'ConvertFrom', 'datenum');
sprintf('Starting Date: %s', string(survey_dates(1)))
sprintf('Ending Date: %s', string(survey_dates(end)))

answer = questdlg('Are you happy with date range?', 'Date range confirmation?', 'Yes', 'No', 'Yes');
switch answer
    case 'No'
        dates_to_use = string(inputdlg({'Start date (YYYYMMDD)', 'End date (YYYYMMDD)'}));
        [~,id_start] = min(abs(survey_dates - datetime(dates_to_use(1), 'InputFormat', 'yyyyMMdd')));
        [~,id_end] = min(abs(survey_dates - datetime(dates_to_use(2), 'InputFormat', 'yyyyMMdd')));
        survey_dates = survey_dates(id_start:id_end);
end

%% =============== Create DEM  ==========================================
for ii = 1:length(survey_dates)
    disp(survey_dates(ii))
    [DEM(ii)] = make_DEM(survey_dates(ii), MOP_files, Eastings, Northings);
end
DEM

% remove NaNed survey
for ii = length(DEM):-1:1
    if isempty(DEM(ii).X)
        DEM(ii)=[];
    end
end

% only keep unique dates
dates=unique([DEM.time]);
for ii = 1:length(dates)
    id= find(dates(ii)==[DEM.time]);
    if length(id) > 1
        if sum(DEM(id(1)).Z(:)-DEM(id(2)).Z(:), 'omitnan') == 0
            DEM(id(2:end))=[];
        end
    end
end
%% =============== Get daily min tide ======================================
for ii = 1:length(DEM)
    date = DEM(ii).time;
     tide_gauge = '9410230'; % NOAA tide gauge at Scripps Institution of Oceanography
            [~,~,verified,~,~] = getNOAAtide(datetime(year(date), month(date), day(date), 0,0,0), datetime(year(date), month(date), day(date), 23,59,59),tide_gauge);
            min_tide = min(verified);
            clear aa
            DEM(ii).min_tide = min_tide;
end
%% Sample Plot
% figure(1);clf
% for ii = 1:length(DEM)
%     if ~isempty(DEM(ii).X)
%         nexttile()
%         pcolor(Eastings, Northings, DEM(ii).Z)
%         colormap(cmocean('topo', 'pivot', 0))
%         shading interp
%         title(string(DEM(ii).time))
%     end
% end
%cbh = colorbar;
%cbh.Layout.Tile = 'east';

clearvars mop_dir MOP_files Mopnum origin_grid Product info Eastings Northings mop_numbers survey_dates dates id ii tide_gauge min_tide date
%% make_DEM function
function [DEM] = make_DEM(date, MOP_files, Eastings, Northings)
for ii = 1:length(MOP_files)
    clear SA X1D Z1D Jidx id
    load(fullfile(MOP_files(ii).folder, MOP_files(ii).name), 'SA')

    Ytol=50; % max dist (m) a survey point can be from the transect
    Xtol=5; % max alongtransect gap (m) that will filled with linear interpolation
    [X1D,Z1D]=GetAllNearestPointsProfiles(SA,Ytol,Xtol);

    Jidx=find(~contains({SA.File}','jumbo','IgnoreCase',true)==1); Z1D(Jidx,:) = []; SA(Jidx)=[];
    %Jidx=find(nanmin(Z1D') > -1); Z1D(Jidx,:) = []; SA(Jidx)=[];

    [~,id]=min(abs(datenum(date)- [SA.Datenum]));
    if abs(days(date - datetime(SA(id).Datenum, 'ConvertFrom', 'datenum'))) < 7
        survey(ii).time = datetime(SA(id).Datenum, 'ConvertFrom', 'datenum');
        survey(ii).Mopnum = SA(id).Mopnum;

        [Xutm,Yutm]=Mop2UTMcoords(X1D,repmat(SA(id).Mopnum, 1, length(X1D)));
        Z1D = Z1D(id,:);
        Xutm(isnan(Z1D))=[]; Yutm(isnan(Z1D))=[]; Z1D(isnan(Z1D))=[];
        survey(ii).Xutm = Xutm;
        survey(ii).Yutm = Yutm;
        survey(ii).Z1D = Z1D;
        survey(ii).type = SA(id).Source;
    end

end
if exist('survey', 'var')
    survey(cellfun(@isempty, {survey.time}))=[];

    x_mop = [survey.Xutm];
    y_mop = [survey.Yutm];
    z_mop = [survey.Z1D];
    Z = griddata(x_mop, y_mop, z_mop, Eastings, Northings);

    DEM.time = unique([survey.time]);
    DEM.type = {survey.type};
    DEM.MOP = {survey.Mopnum};
    DEM.MOP = [DEM.MOP{:}];
    DEM.X = Eastings;
    DEM.Y = Northings;
    DEM.Z = Z;
else
    DEM.time = date;
    DEM.type = 'NaN';
    DEM.MOP = [];
    DEM.X = [];
    DEM.Y = [];
    DEM.Z = [];
end
end

function [Eastings, Northings] = make_grid(Products)

% Get origin coordinates
[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);

% Reorganize coordinates
if ~isempty(Products.xlim)
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
end % if ~isempty(Products.xlim)
if ~isempty(Products.ylim)
    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
end % if ~isempty(Products.ylim)

ixlim = x2 - Products.xlim;
iylim = y2 + Products.ylim;
[X, Y]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));

Z = X.*0 ;

%% Rotation
localX=X - x2;
localY=Y - y2;

Xout=localX.*cosd(Products.angle-270)+localY.*sind(Products.angle-270);
Yout=localY.*cosd(Products.angle-270)-localX.*sind(Products.angle-270);

xyz = [Xout(:) Yout(:) Z(:)];
xyz = xyz+[x2 y2 0];

localX = -localX;

Eastings = Xout + x2;
Northings = Yout + y2;
end

function [Xutm,Yutm]=Mop2UTMcoords(Xm,Ym)

Nmop=round(Ym); % Mops with data points

% divide mop area into 101 mop subtransects at 1m xshore resolution,
%  with an extra 100m of back beach for each. x1d is the xshore distance
%  from the backbeach line (line connecting Mop backbeach points).
%  xt,yt are the 2d grid locations of the main Mop transect line, and
%  xst,yst are the 2d grid locations for all the subtransects (including
%  the main line)
load MopTableUTM

Xutm=Xm*NaN;Yutm=Ym*NaN; % initialize utm coord vectors

for mop=unique(Nmop)' % loop though range of mop numbers

    % get mop subtransect lines with order 1m alongshore resolution
    [x1d,xt,yt,xst,yst]=GetTransectLines(Mop,mop,101,[-100 500]);

    n=find(Nmop == mop); % index of points closest to this mop number

    % x,y mop coords to subtransect line xst,yst utm location
    ix1d=round(Xm(n))-x1d(1)+1; % Mop coords xshore indices
    ist=round((Ym(n)-mop+.5)*100)+1; % subtransect indices
    idx=sub2ind(size(xst),ist,ix1d); % 1d indices of subtransect points
    % utm coords
    Xutm(n)=xst(idx);
    Yutm(n)=yst(idx);

end

end
end