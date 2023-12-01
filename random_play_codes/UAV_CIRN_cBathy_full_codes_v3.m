%% UAV CIRN & cBathy Workflow

% Requires exiftool, CIRN, and cBathy [current files required some edits
% from default codes - look at AthinaLange GitHub]
%
% drone metadata should given extrinsics
%
% https://www.mathworks.com/matlabcentral/fileexchange/42000-run_exiftool
% https://github.com/Coastal-Imaging-Research-Network/CIRN-Quantitative-Coastal-Imaging-Toolbox/wiki
% https://github.com/Coastal-Imaging-Research-Network/cBathy-toolbox/wiki/cBathy-User-Manual
%
% need gps coordinates of gcp/scp in gps_northings.txt file in flightdate folder
% 
% Athina Lange 2021

%% Housekeeping
clear all
% Find folder/flights in drone/data/cbathy that you want to process

data_path = uigetdir('/Volumes/LANGE_Passport/Drone_videos/','Video Folder')
cd(data_path)
aa=split(data_path,'/');
stationStr = char(aa(end))
close all 
clearvars -except stationStr data_path

% User should make sure that X_CoreFunctions and subfolders are made active
% in their MATLAB path.
addpath(genpath(fullfile('/Volumes/LANGE_Passport/DRONE_PROCESSING_CODES/')))

setenv('PATH', [getenv('PATH') ':/usr/local/bin']);
%process_ig8_output_athina % process gcp file

clearvars -except stationStr data_path
flights = dir(pwd); flights(1:2)=[]; 
for ii=1:length(flights);aa(ii)=flights(ii).isdir;end;flights(aa==0)=[];
for ii=length(flights):-1:1; if contains(flights(ii).name, 'timestacks'); flights(ii)=[];end; end;
flights = char(flights.name);
num_flights = length(flights);
%% Get IG8 GCP file in correct format
%process_ig8_output_athina
movefile([stationStr(1:8) '_gcp.txt'], 'gps_northings.txt')
%% ========================================================================
%                                   CIRN
% =========================================================================
%% Loop through all flights from day - extract images
for nn = 1:num_flights
    %% Define file location
    video_path = [data_path '/' flights(nn,:)]
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    mkdir('Processed_data')
    %% FILE NAMES
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    
    %% Drone Coordinates
    % load metadata information
    % Get exif data
    system(sprintf('exiftool -filename -CreateDate -Duration -CameraPitch -CameraYaw -CameraRoll -AbsoluteAltitude -RelativeAltitude -GPSAltitude -GPSCoordinates -GPSLatitude -GPSLongitude -Latitude -Longitude -RtkFlag -RtkStdHgt -RtkStdLat -RtkStdLon -GPSSatellites -csv -c "%%.20f" %s/DJI_0* > %s/%s', odir, odir, csvname))
    
    C = readtable([odir '/' csvname])
    format long
    % get indices of images and videos to extract from
    form = char(C.FileName);
    form = string(form(:,end-2:end));
    jpg_id = find(form == 'JPG');jpg_id = jpg_id(1);
    mov_id = find(form == 'MOV');

    % % check that only 5:28min videos are used (removing extra short segments)
    % clear aa
    % for ii = 1:size(C,1)
    % aa(ii)=C.Duration(ii);
    % end
    % aa=char(aa); 
    % mov_id = find(contains(string(aa),"0:05:28")==1);
    
    % pull RTK-GPS coordinates from image and change to Eastings/Northings
    % requires intg2012b and ll_to_utm codes (reefbreak server)
    lat = char(C.GPSLatitude(jpg_id));
    lat = str2double(lat(1:10));
    long = char(C.GPSLongitude(jpg_id));
    if long(end) == 'W'
        long = str2double(['-' long(1:11)]);
    else
        long = str2double(long(1:11));
    end
    [zgeoid_offset] = intg2012b(lat,long);
    [UTMNorthing, UTMEasting, UTMZone] = ll_to_utm(lat, long);
    save('Processed_data/C', 'UTMNorthing', 'UTMEasting', 'zgeoid_offset', 'jpg_id', 'mov_id', 'lat', 'long', 'C')
    %% A0 - Image Extraction - 2Hz
    % Location where images will be saved
    tic
    mkdir('images')
    idir = [odir  '/images/'];
    
    % Enter the Desired Frame Rate in frames/second (fps). 
    frameRate = 2; %fps
    if size(dir(['images' '/*.jpg' ]),1) < 655*length(mov_id)
    for jj = 1:length(mov_id)
        mkdir(['images/' char(string(jj))])
        system(['ffmpeg -i ' char(string(C.FileName(mov_id(jj)))) ' -qscale:v 2 -r ' char(string(frameRate)) ' images/'  char(string(jj)) '/Frame_%04d.jpg'])
    end
    end
    
    for jj = 1:length(mov_id)
        if jj == 1
            movefile(['images/' char(string(jj)) '/*'], 'images/')
            rmdir(['images/' char(string(jj))])
        else
            % figure out nameshift
            aa=dir('images'); aa([aa.isdir]==1)=[];
            id=[];for ii = 1:length(aa);ac = contains(aa(ii).name, 'Frame'); if ac == 0; id = [id ii];end;end
            nameshift = str2double(aa(end).name(7:10))
            % find names of new folder
            ab=dir(['images/' char(string(jj))]); ab([ab.isdir]==1)=[];
            id=[];for ii = 1:length(ab);ac = contains(ab(ii).name, 'Frame'); if ac == 0; id = [id ii];end;end
            ab(id)=[];
    
            for mm = 1:length(ab)
                name = str2double(ab(mm).name(7:10))+nameshift;
                if name < 100
                    movefile(['images/' char(string(jj)) '/' ab(mm).name], ['images/Frame_00' char(string(name)) '.jpg'])
                elseif name < 1000
                    movefile(['images/' char(string(jj)) '/' ab(mm).name], ['images/Frame_0' char(string(name)) '.jpg']) 
                elseif name > 1000
                    movefile(['images/' char(string(jj)) '/' ab(mm).name], ['images/Frame_' char(string(name)) '.jpg'])
                end
            end
            delete(['images/' char(string(jj)) '/*'])
            rmdir(['images/' char(string(jj))])
        end
    end
    toc
    % check that Actual Average dt: 0.5005s
    % check that STD of actual dt: 0.00050038s
    %% A0 - Image Extraction - 10Hz
    % Location where images will be saved
    mkdir('images_10Hz')
    idir = [odir '/images_10Hz/'];
    % Enter the Desired Frame Rate in frames/second (fps). 
    frameRate = 10; %fps
    if size(dir(['images_10Hz' '/*.jpg' ]),1) < 3278*length(mov_id)
        for jj = 1:length(mov_id)
            mkdir(['images_10Hz/' char(string(jj))])
            system(['ffmpeg -i ' char(string(C.FileName(mov_id(jj)))) ' -qscale:v 2 -r ' char(string(frameRate)) ' images_10Hz/'  char(string(jj)) '/Frame_%04d.jpg'])
        end
    end
    
    for jj = 1:length(mov_id)
        if jj == 1
            movefile(['images_10Hz/' char(string(jj)) '/*'], 'images_10Hz/')
            rmdir(['images_10Hz/' char(string(jj))])
        else
            % figure out nameshift
            aa=dir('images_10Hz'); aa([aa.isdir]==1)=[];
            id=[];for ii = 1:length(aa);ac = contains(aa(ii).name, 'Frame'); if ac == 0; id = [id ii];end;end
            nameshift = str2double(aa(end).name(7:10))
            % find names of new folder
            ab=dir(['images_10Hz/' char(string(jj))]); ab([ab.isdir]==1)=[];
            id=[];for ii = 1:length(ab);ac = contains(ab(ii).name, 'Frame'); if ac == 0; id = [id ii];end;end
            ab(id)=[];
    
            for mm = 1:length(ab)
                name = str2double(ab(mm).name(7:10))+nameshift;
                if name < 100
                    movefile(['images_10Hz/' char(string(jj)) '/' ab(mm).name], ['images_10Hz/Frame_00' char(string(name)) '.jpg'])
                elseif name < 1000
                    movefile(['images_10Hz/' char(string(jj)) '/' ab(mm).name], ['images_10Hz/Frame_0' char(string(name)) '.jpg']) 
                elseif name > 1000
                    movefile(['images_10Hz/' char(string(jj)) '/' ab(mm).name], ['images_10Hz/Frame_' char(string(name)) '.jpg'])
                end
            end
            delete(['images_10Hz/' char(string(jj)) '/*'])
            rmdir(['images_10Hz/' char(string(jj))])
        end
    end
    toc
    % check that Actual Average dt: 0.01001s
    % check that STD of actual dt: 0.00030001s
    cd('..')

end % end num_flights loop

%% Loop through all flights from day - clicking step
for nn = 1:num_flights
    %% FILE NAMES
    video_path = [data_path '/' flights(nn,:) '/']
    cd(video_path)
    mkdir('Processed_data')
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    %% Coordinates
    load('Processed_data/C')
    %% A - Intrinsics
    % pull camera intrinsics from pre-calibrated values
    % set to whether distortion already fixed in videos or not
    date = datetime(stationStr(1:8),'InputFormat', 'yyyyMMdd');
    if date < datetime(2022, 07, 01) % Before July 2022
        load('/Volumes/LANGE_Passport/Drone_videos/cameraParams_whitecap.mat')
    else
        load('/Volumes/LANGE_Passport/Drone_videos/cameraParams_Theia.mat')
    end
    
    [ind_distortion,tf] = listdlg('ListString',[{'Off / Distorted'}, {'On / Undistorted'}], 'SelectionMode','single', 'InitialValue',[2], 'PromptString', {'Distortion correction On/Off?'});
    if ind_distortion == 1
        cameraParams = cameraParams_distorted;
    elseif ind_distortion == 2
        cameraParams = cameraParams_undistorted;
    end
    
    intrinsics(1) = cameraParams.ImageSize(2);            % Number of pixel columns
    intrinsics(2) = cameraParams.ImageSize(1);            % Number of pixel rows
    intrinsics(3) = cameraParams.PrincipalPoint(1);         % U component of principal point  
    intrinsics(4) = cameraParams.PrincipalPoint(2);          % V component of principal point
    intrinsics(5) = cameraParams.FocalLength(1);         % U components of focal lengths (in pixels)
    intrinsics(6) = cameraParams.FocalLength(2);         % V components of focal lengths (in pixels)
    intrinsics(7) = cameraParams.RadialDistortion(1);         % Radial distortion coefficient
    intrinsics(8) = cameraParams.RadialDistortion(2);         % Radial distortion coefficient
    intrinsics(9) = cameraParams.RadialDistortion(3);         % Radial distortion coefficient
    intrinsics(10) = cameraParams.TangentialDistortion(1);        % Tangential distortion coefficients
    intrinsics(11) = cameraParams.TangentialDistortion(2);        % Tangential distortion coefficients
    %
    if ind_distortion == 2
        intrinsics(7:11) = 0; % no distortion (if distortion correction on)
    end
    save([odir '/Processed_data/' oname '_IO'], 'intrinsics')
    
    %% E - Choosing SCP
    % click on scp point, give it a number (matches the number in gps.txt), 
    % choose radius of pixel frame to look around the reprojected coordinate 
    % (typically between 15-8 for our targets), then set the intensity 
    % threshold (ma1ke sure only the scp point shows up - code will take the 
    % average location of all the points above the threshold)
    % scp's do NOT need to be the same as gcp (but they do need to remain
    % visible for the whole sequence of images)
    
    idir = [odir  '/images/'];
    
    imageDirectory = idir;
    L=sort(split(string(ls(imageDirectory)))); L=L(2:end); % Athina: changes
    imagePath= append(imageDirectory,L(1));
    
    E_scpSelection
    
    gcp = scp;
    gcp=rmfield(gcp,'R'); gcp=rmfield(gcp,'T'); gcp=rmfield(gcp,'brightFlag');
    save([odir '/Processed_data/' oname '_gcpUVdInitial' ],'gcp')
    
    %% C - Choosing GCP : confirm gcp used
    % will pull gcp gps.txt file into subdirectory
    %                            -> update as new flights come in
    % click on choosen gcp from B
        gcpCoord= [stationStr '; NAVD88; meters'];
        if ~isfile('gps_northings.txt')
            copyfile([odir(1:end-size(flights,2)) 'gps_northings.txt'])
        end
        ab = importdata([odir '/gps_northings.txt']); ab = [ab(:,1) ab(:,4)];
        for ii = 1:length(ab)
	        gcp_all{ii} = strcat(string(ab(ii,1)), ' :  ', string(ab(ii,2)), 'm');
        end
    
        gcp_all = gcp_all';
    
        for gg = 1:length(gcp); gcpsUsed(gg) = gcp(gg).num; end
    
        extrinsicsInitialGuess= [UTMEasting UTMNorthing C.RelativeAltitude(jpg_id)-zgeoid_offset deg2rad(C.CameraYaw(jpg_id)+360) deg2rad(C.CameraPitch(jpg_id)+90) deg2rad(C.CameraRoll(jpg_id))]; % [ x y z azimuth tilt swing]
        extrinsicsKnownsFlag= [0 0 0 0 0 0];  % [ x y z azimuth tilt swing]

        C_singleExtrinsicSolution
        extrinsics(3)=ceil(C.RelativeAltitude(jpg_id))-zgeoid_offset;
        save([odir '/Processed_data/' oname '_IOEOInitial' ],'initialCamSolutionMeta','extrinsics','intrinsics')

    cd('..')
    %clearvars -except num_flights flights data_path stationStr jpg_id
end % end num_flights loop

%% Loop through all flights from day - processing step - check grid size
for nn = num_flights
    %% FILE NAMES
    video_path = [data_path '/' flights(nn,:)]
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    %% Drone Coordinates
    load('Processed_data/C')
    %% D - rectified grid : 2Hz
    % Backbeach location of center MOP line (Lat, Lon), cross-shore width, along-shore width, grid size, MOP angle    
    
    % Torrey Local Grid - 582
    grid_all{1,1} = {'32.9272', '-117.2596', '1000', '1600', '1', '262.01'};
    % Cardiff Local Grid - 
    grid_all{1,2} = {'33.0025', '-117.2781', '1000', '2000', '5', '267.53'};
    % SIO Local Grid -
    grid_all{1,3} = {'32.86667', '-117.2536', '300', '400', '5', '280.99'};
    % Carmel Local Grid - 
    grid_all{1,4} = {'36.536722', '-121.9261', '1000', '2000', '5', '253.55'};
    % Pajaro Local Grid - 
    grid_all{1,5} = {'36.8504565', '-121.8096381', '1000', '2000', '5', '244.01'};
    % Torrey North Local Grid - 590
    grid_all{1,6} = {'32.9344', '-117.2607', '1000', '1600', '1', '261.5'};
    
    locations = string({'Torrey 582', 'Cardiff', 'SIO', 'Carmel', 'Pajaro', 'Torrey 590 (Esturary)'});
    [grid_num,tf] = listdlg('ListString', locations, 'SelectionMode','single', 'InitialValue',[1], 'PromptString', {'Location of flight'});
    %grid_num = find(locations == stationStr(10:end));
    grid = grid_all{1,grid_num};
    
    frameRate = 2
    lat = str2num(string(grid(1))); % N
    long = str2num(string(grid(2)));% W
    [y2,x2, ~] = ll_to_utm(lat, long);
    
    localOrigin = [x2,  y2];
    localAngle = 270-str2num(string(grid(6)));
    
    ixlim = [x2-str2num(string(grid(3))) x2];
    iylim = [y2-str2num(string(grid(4)))/2 y2+str2num(string(grid(4)))/2];
    if grid_num == 2 % Cardiff
        iylim = [y2-300 y2+str2num(string(grid(4)))-300];
    end
    idxdy = str2num(string(grid(5)));
    
    idir = [odir '/images_10Hz/']
    %idir = ['/Volumes/drone/data/cbathy/20211026_Torrey/' char(string(nn)) '/images/']
    imageDirectory = idir;
    L=sort(split(string(ls(imageDirectory)))); L=L(2:end); % Athina: changes
    imagePath= append(imageDirectory,L(1));
    ioeopath = [odir '/Processed_data/' oname '_IOEOInitial' ]
    D_gridGenExampleRect
    figure(2)
    savefig('Processed_data/Grid')
   
    %% F - Extrinsics : confirm scp used 2Hz
    
    ab = importdata([odir '/gps_northings.txt']); ab = [ab(:,1) ab(:,4)];
    load([odir '/Processed_data/' oname '_scpUVdInitial' ])
    for ss = 1:length(scp); ind_scp(ss) = scp(ss).num; end
    scpz = ab(ind_scp,:);
    
    to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles');
    to.TimeZone = 'UTC'
    to = datenum(to);
    %  Enter the dt in seconds of the collect. If not known, leave as {}. Under
    %  t, images will just be numbered 1,2,3,4.
    frameRate = 2;
    dts= 1./frameRate; %Seconds

    idir = [odir '/images/'];
    imageDirectory = idir;
    L = sort(split(string(ls(imageDirectory)))); L = L(2:end); % Athina: changes
    imagePath = append(imageDirectory,L(1));
    F_image_by_image
    % if F_variableExtrinsicSolutions fails, run F_image_by_image
    % find k for frame number

    savefig('Processed_data/Extrinsics_2Hz')
    close all
    %% F - Extrinsics : confirm scp used 10Hz
    % click on all your chosen scp
    
    ab = importdata([odir '/gps_northings.txt']); ab = [ab(:,1) ab(:,4)];
    load([odir '/Processed_data/' oname '_scpUVdInitial' ])
    for ss = 1:length(scp); ind_scp(ss) = scp(ss).num; end
    scpz = ab(ind_scp,:);
    
    to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles');
    to.TimeZone = 'UTC'
    to = datenum(to);
    %  Enter the dt in seconds of the collect. If not known, leave as {}. Under
    %  t, images will just be numbered 1,2,3,4.
    frameRate = 10;
    dts= 1./frameRate; %Seconds

    idir = [odir '/images_10Hz/'];
    imageDirectory = idir;
    L = sort(split(string(ls(imageDirectory)))); L = L(2:end); % Athina: changes
    aa = regexp(L, '\d+', 'match'); aa = str2double(string((aa)));
    [~, id] = sort(aa); L = L(id);
    imagePath = append(imageDirectory,L(1));
    F_image_by_image
    
    savefig('Processed_data/Extrinsics_10Hz')  
    close all
end
%% Loop through pixel extraction
for nn = num_flights
    %% FILE NAMES
    video_path = [data_path '/' flights(nn,:)]
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    %% Drone Coordinates
    load('Processed_data/C')
    %% G2 - getting pixel intensity Grid
    % computes the pixel intensity time series for every grid point
    clear ioeopath imageDirectory
    frameRate = 2
    idir = [odir  '/images_10Hz/'];
    imageDirectory = idir;
    L=sort(split(string(ls(imageDirectory)))); L=L(2:end); % Athina: changes
    imagePath= append(imageDirectory,L(1));
    ioeopath = [odir '/Processed_data/' oname '_' char(string(frameRate)) '_IOEOVariable.mat'];
    gname = [oname '_NAVD88_Bingchen.mat'];
    
    clear pixInst
    localFlag = 1;
    
    pixInst.type='Grid';
    pixInst.dx = 0.1;%str2num(string(grid(5))); % 5
    pixInst.dy = 0.1;%str2num(string(grid(5))); % 5
    pixInst.xlim = [localX(1) localX(end)];
    pixInst.ylim = [localY(1) localY(end)];
    pixInst.z={}; % Leave empty if you would like it interpolated from input
    
    G2_pixelInstruments
    
    %% G2 - getting pixel intensity Transects
    % computes the pixel intensity time series for every grid point
    clear ioeopath imageDirectory
    frameRate = 10
    idir = [odir  '/images_10Hz/'];
    imageDirectory = idir;
    L=sort(split(string(ls(imageDirectory)))); L=L(2:end); % Athina: changes
    imagePath= append(imageDirectory,L(1));
    ioeopath = [odir '/Processed_data/' oname '_' char(string(frameRate)) '_IOEOVariable.mat'];
    gname = [oname '_NAVD88.mat'];
    
    clear pixInst
    localFlag=1
    if grid_num == 1 % Torrey 582
        for ii = 1:9
            pixInst(ii).type='xTransect';
            pixInst(ii).dx =.1;
            pixInst(ii).xlim = [-500 0];
            pixInst(ii).z={}; % Leave empty if you would like it interpolated from input
        end
        
        pixInst(1).y = -300; % 579
        pixInst(2).y = -200; % 580
        pixInst(3).y = -100; % 581
        pixInst(4).y = 0; % 582
        pixInst(5).y = 33; % 582.3
        pixInst(6).y = 66; % 582.6
        pixInst(7).y = 100; % 583
        pixInst(8).y = 200; % 584
        pixInst(9).y = 300; % 585
    elseif grid_num == 6 % Torrey 590
        for ii = 1:12
            pixInst(ii).type='xTransect';
            pixInst(ii).dx =.1;
            pixInst(ii).xlim = [-500 0];
            pixInst(ii).z={}; % Leave empty if you would like it interpolated from input
        end
        pixInst(1).y = -200; % 588
        pixInst(2).y = -100; % 589
        pixInst(3).y = -75; % 589.25
        pixInst(4).y = -50; % 589.5
        pixInst(5).y = -25; % 589.75
        pixInst(6).y = 0; % 590
        pixInst(7).y = 25; % 590.25
        pixInst(8).y = 50; % 590.5
        pixInst(9).y = 75; % 590.75
        pixInst(10).y = 100; % 591
        pixInst(11).y = 150; % 591.5
        pixInst(12).y = 200; % 592

    end
    
    G2_pixelInstruments
    
    imwrite(pixInst(1).Irgb,[stackName '_588.png'])
    imwrite(pixInst(2).Irgb,[stackName '_589.png'])
    imwrite(pixInst(3).Irgb,[stackName '_589.25.png'])
    imwrite(pixInst(4).Irgb,[stackName '_589.5.png'])
    imwrite(pixInst(5).Irgb,[stackName '_589.75.png'])
    imwrite(pixInst(6).Irgb,[stackName '_590.png'])
    imwrite(pixInst(7).Irgb,[stackName '_590.25.png'])
    imwrite(pixInst(8).Irgb,[stackName '_590.5.png'])
    imwrite(pixInst(9).Irgb,[stackName '_590.75.png'])
    imwrite(pixInst(10).Irgb,[stackName '_591.png'])
    imwrite(pixInst(11).Irgb,[stackName '_591.5.png'])
    imwrite(pixInst(12).Irgb,[stackName '_592.png'])
    %% Save files
    save('Processed_data/CIRN', '-v7.3')
    clearvars -except num_flights flights data_path stationStr jpg_id
    cd('..')
end

%% ========================================================================
%                               cBathy 2.0
% =========================================================================
%% Flip CIRN for cBathy
for nn = 1:num_flights
    video_path = [data_path '/' flights(nn,:)]
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    
    % Get CIRN into cBathy format
    % cBathy assumes an east coast beach, so coordinates need to be flipped
    % 180deg. 
    % cBathy needs xyz, data, t
    load(['Processed_data/' stationStr '_2_pixInst.mat'])
    Igray = pixInst(1).Igray;
    % Remove Nans
    [r c tt]=size(Igray);
    for k=1:r
        for j=1:c
            bind =find(isnan(Igray(k,j,:))==1);
            gind =find(isnan(Igray(k,j,:))==0);
    
            Igray(k,j,bind)=nanmean(Igray(k,j,gind));
        end
    end
    
    % Rotate Coordinate System
    [Xout, Yout]= localTransformPoints([pixInst(1).X(end,end) pixInst(1).Y(end,end) ],180,1,pixInst(1).X,pixInst(1).Y);
    
    %Demo Plot
    figure
    pcolor(pixInst(1).X,pixInst(1).Y,Igray(:,:,1))
    shading flat
    figure
    pcolor(Xout,Yout,Igray(:,:,1))
    shading flat
    
    xyz=[Xout(:) Yout(:) pixInst(1).Z(:)];
    
    m = size(Igray,1);
    n = size(Igray,2);
    tt = size(Igray,3);
    data=zeros(tt,m*n);
    
    [xindgrid,yindgrid]=meshgrid(1:n,1:m);
    rowIND=yindgrid(:);
    colIND=xindgrid(:);
    
    for i=1:length(rowIND(:))
        data(:,i)=reshape(Igray(rowIND(i),colIND(i),:),tt,1);
    end
    save([odir '/Processed_data/' stackName '.mat'], 'xyz', 'data', 't','pixInst', 'flights', 'num_flights', '-v7.3')
    cd('..')
end

%% Run cBathy
for nn = 1:num_flights
    %% FILE NAMES
    video_path = [data_path '/' flights(nn,:)]
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    
    %% Loading CIRN data
    % remove all unnecessary loaded variables
    % load previously saved cBathy input data
    addpath(genpath('/Volumes/LANGE_Passport/DRONE_PROCESSING_CODES/cBathy_2.0'))
    
    clearvars -except data_path nn flights num_flights odir oname stackName stationStr filename
    load([odir '/Processed_data/' stackName '.mat'])
    
    % Fill in cam requirement
    cam = xyz.*0 + 1;
    % Get into Epoch time
    epoch = (t-datenum(1970,1,1))*24*3600;
    %% CBathy Parameters
    % cBathyTideTorrey pulls from NOAA SIO tide gauge. If tide different, use different function
    
    %%% Site-specific Inputs
    params.stationStr = stationStr;
    params.dxm = 5;%5;                    % analysis domain spacing in x
    params.dym = 10;%10;                   % analysis domain spacing in y
    max_x = max(xyz(:,1));                
    min_x = min(xyz(:,1));
    max_y = max(xyz(:,2));                
    min_y = min(xyz(:,2));
    
    params.xyMinMax = [min_x max_x min_y max_y];%[110 1265 1050 1200];%[min(xyz(:,1)) max(xyz(:,1)) min(xyz(:,2)) max(xyz(:,2))];   % min, max of x, then y
                                        % default to [] for cBathy to choose
    params.tideFunction = 'cBathyTideTorrey';  % tide level function for evel
    %params.tideFunction = 'cBathyTideneutral';  % tide level function for evel
    
    %%%%%%%   Power user settings from here down   %%%%%%%
    params.MINDEPTH = 0.25;             % for initialization and final QC
    params.MAXDEPTH = 20;             % for initialization and final QC
    params.QTOL = 0.5;                  % reject skill below this in csm
    params.minLam = 12;                 % min normalized eigenvalue to proceed
    params.Lx = 50;%3*params.dxm;           % tomographic domain smoothing
    params.Ly = 100;%3*params.dym;           % 
    params.kappa0 = 2;                  % increase in smoothing at outer xm
    params.DECIMATE = 1;                % decimate pixels to reduce work load.
    params.maxNPix = 80;                % max num pixels per tile (decimate excess)
    params.minValsForBathyEst = 4;      % need this many pixels to solve
    params.shortLengthNFreqs = 4;       % need this many for coherence sorting
                                        % versus magnitude shorting
    
    % f-domain etc.
    params.fB = [1/18: 1/50: 1/4];		% frequencies for analysis (~40 dof)
    params.nKeep = 4;                   % number of frequencies to keep
    
    % debugging options
    params.debug.production = 0;
    params.debug.DOPLOTSTACKANDPHASEMAPS = 0;  % top level debug of phase
    params.debug.DOSHOWPROGRESS = 1;		  % show progress of tiles
    params.debug.DOPLOTPHASETILE = 0;		  % observed and EOF results per pt
    params.debug.TRANSECTX = 200;		  % for plotStacksAndPhaseMaps
    params.debug.TRANSECTY = 900;		  % for plotStacksAndPhaseMaps
    
    % default offshore wave angle.  For search seeds.
    params.offshoreRadCCWFromx = 0;
    params.nlinfit = 1; % flag, 0 = use LMFnlsq.m to do non-linear fitting

    %% Run Cbathy
    bathy.params = params;
    bathy.epoch  = num2str(epoch(1));
    bathy.sName  = stackName;
    
    bathy = analyzeBathyCollect(xyz, epoch, (data), cam, bathy);
    close all
    figure
    bathy.params.debug.production = 1;
    plotBathyCollect(bathy)
    sgtitle([[stationStr(1:8) ' - ' stationStr(10:end)] string(stackName(end-1:end))])
    savefig('Processed_data/Bathy_v2')
    close all

    %% Rotate back to West Coast
    [Xo, Yo]=meshgrid(bathy.xm,bathy.ym);
    [Eout, Nout]= localTransformPoints([pixInst(1).X(end,end) pixInst(1).Y(end,end) ],180,0,Xo,Yo);
    bathy.coords.Xo = Xo; bathy.coords.Eout = Eout;
    bathy.coords.Yo = Yo; bathy.coords.Nout = Nout;
    save([odir '/Processed_data/cBathy_' stackName '_v2.mat'], '-v7.3')
    save([odir '/Processed_data/cBathy_Results_' stackName '_v2.mat'], 'bathy', '-v7.3')
    
    cd('..')
end
%%
%% ========================================================================
%                               Timestack
% =========================================================================
%% run WaveCrestDetection on all timestacks
mkdir([data_path '/timestacks/processed'])
mkdir([data_path '/timestacks/data'])
for nn = 1:num_flights
    copyfile([data_path '/' flights(nn,:) '/*.png'], [data_path '/timestacks/data/'])
end
timestack_all = dir([data_path '/timestacks/data/']);
for nn = length(timestack_all ):-1:1 
    if timestack_all(nn).name(1) == '.'
        timestack_all(nn)=[];
    end
end
% system(['conda activate pytorch'])
% system(['cd /Volumes/LANGE_Passport/DRONE_PROCESSING_CODES/WaveCrestDetection/'])
% for nn = 1:length(timestack_all)
%     system(['python predict.py --load model_epoch50.pth --processing-window-bottom 4700 --image ' data_dir '/timestacks/data/' timestack_all(nn).name '.png --filter-interactive 0'])
% end

% move processed timestacks to timestacks/processed folder
%% ========================================================================
%                         compute composite bathy
% =========================================================================


%% Create survey grid to pull from
load('MopTableUTM.mat')
x10 = [0:0.1:500]';
locations = string({'Torrey 582', 'Cardiff', 'SIO', 'Carmel', 'Pajaro', 'Torrey 590 (Esturary)'});
[grid_num,tf] = listdlg('ListString', locations, 'SelectionMode','single', 'InitialValue',[1], 'PromptString', {'Location of flight'});
    
if grid_num == 1
    mop_bb = 582
elseif grid_num == 2 % Cardiff
    mop_bb = 668
elseif grid_num == 3 % SIO
    mop_bb = 513
elseif grid_num == 6 % Torrey Esturary
    mop_bb = 590
end

date = datetime(stationStr(1:8), 'InputFormat', 'yyyyMMdd')
mop_max = mop_bb + 10;
mop_min = mop_bb - 10;
moplines = [mop_min:mop_max];
angle = Mop(mop_bb).Normal;
% rotate grid to local angle (like in D)
rotation = 270 - angle;
alpha_rad = rotation*pi/180; 
rot_mat   = [ cos(alpha_rad)  sin(alpha_rad); % Assuming a LH coordinate system -> CW rotation
                     -sin(alpha_rad) cos(alpha_rad)];

survey.date = date;
survey.moplines = moplines;
jj=0;
for mm = moplines
    jj=jj+1;
    clear d
    load(['/Volumes/group/MOPS/M00' char(string(mm)) 'SM.mat']);
    for ii = 1:length(SM)
        SM(ii).datetime = datetime(SM(ii).Datenum, 'ConvertFrom', 'datenum');
        d(ii)=SM(ii).Datenum; d2(ii)=d(ii);
        if string(SM(ii).Source) == 'iG8wheel'
            d(ii)=NaN;
        end
    end
    mop_check = 0;
    while mop_check ==0
        [~,ind]=min(abs(d - datenum(date)));

        if min(SM(ind).Z1Dmedian) < -8
             mop_check = 1;
             SM(ind).datetime;
        
            % rotating stuff
            xx_full = [Mop(mm).BackXutm:-1:Mop(mm).OffXutm];
            yy_full = linspace(Mop(mm).BackYutm, Mop(mm).OffYutm, length(xx_full));
        
            x = SM(ind).X1D;
            z = SM(ind).Z1Dmedian;
            zmin = SM(ind).Z1Dmin;
            zmax = SM(ind).Z1Dmax;
            zstd = SM(ind).Z1Dstd;
            id=find(x==0);
            x(1:id-1)=[]; % x = 0 matches X backbeach
            z(1:id-1)=[];
            zmin(1:id-1)=[]; zmax(1:id-1)=[]; zstd(1:id-1)=[];
            if length(z) >= length(xx_full)
                x(length(xx_full)+1:end)=[];
                z(length(xx_full)+1:end)=[];
                zmin(length(xx_full)+1:end)=[]; zmax(length(xx_full)+1:end)=[]; zstd(length(xx_full)+1:end)=[];
            elseif length(z) < length(xx_full)
                xx_full(length(z)+1:end)=[];
                yy_full(length(z)+1:end)=[];
            end
            % Translate and Rotate to Timestack Grid
            uv_full = -rot_mat*[xx_full'-Mop(mop_bb).BackXutm yy_full'-Mop(mop_bb).BackYutm]';
            X_true = uv_full(1,:).'; 
            Y_true = uv_full(2,:).';
            z = interp1(X_true, z, x10);
            z_min = interp1(X_true, zmin, x10);
            z_max = interp1(X_true, zmax, x10);
            z_std = interp1(X_true, zstd, x10);

            survey.z(jj,:)=z;
            survey.zmin(jj,:)=z_min;
            survey.zmax(jj,:)=z_max;
            survey.zstd(jj,:)=z_std;
            
        else
            d(ind)=NaN;
        end
    end
    survey.surveydate{jj} = SM(ind).datetime;
end


clear mopgrid
mopgrid = [survey.moplines(1):0.25:survey.moplines(end)];

[X,Y] = meshgrid(x10, mopgrid);
survey.mopgrid = mopgrid';
survey.zinterp = interp2(x10, survey.moplines, survey.z, X,Y);

if mop_bb == 590 % Esturary mouth and weird bathy
    survey.zinterp(39,:) = nanmean([survey.z(10,:); survey.z(12,:)]);
    survey.zinterp(40,:) = nanmean([survey.z(10,:); survey.z(12,:)]);
    survey.zinterp(42,:) = nanmean([survey.z(10,:); survey.z(12,:)]);
    survey.zinterp(43,:) = nanmean([survey.z(10,:); survey.z(12,:)]);

end
save([data_path '/survey.mat'], 'survey')


%% Create cBathy grid to pull from
load([data_path '/survey.mat'])
for ii = 1%:num_flights
     %% FILE NAMES
    video_path = [data_path '/' flights(nn,:)]
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    load('Processed_data/C')

    date_start = datetime(C.CreateDate(1), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles'); date_start.TimeZone = 'UTC';
    date_end = datetime(C.CreateDate(end), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles'); date_end.TimeZone = 'UTC';
    [~,~,verified,~,~] = getNOAAtide(date_start, date_end, '9410230', 'NAVD');
    tide = nanmean(verified);
    
    date = datetime(stationStr(1:8), 'InputFormat', 'yyyyMMdd');
    cbathy(ii).date = date;

    load([odir '/Processed_data/cBathy_Results_' stackName '_v2.mat'])
    % check if tide already included or not
    if isnan(bathy.tide.zt)==0
        tide = 0;
    end

    ax = x10;
    ay = survey.mopgrid;
    [X,Y]=meshgrid(ax,ay);
    z_temp = interp2(-fliplr(bathy.coords.Eout), -fliplr(bathy.coords.Nout)./100+mop_bb, fliplr(-bathy.fCombined.h), X,Y);
    z = z_temp+tide;
    zerr = interp2(-fliplr(bathy.coords.Eout), -fliplr(bathy.coords.Nout)./100+mop_bb, fliplr(bathy.fCombined.hErr), X,Y);

    cbathy(ii).hover = str2double(filename);
    cbathy(ii).x = X;
    cbathy(ii).y = Y;
    cbathy(ii).z = z;
    cbathy(ii).zerr = zerr;
    cbathy(ii).tide = tide;

    cd ..
end
for ii = 1:length(cbathy)
    cbathy(ii).zerr(cbathy(ii).z < -20)=NaN;
    cbathy(ii).z(cbathy(ii).z < -20)=NaN;
    cbathy(ii).z(cbathy(ii).zerr > 30)=NaN;
    cbathy(ii).zerr(cbathy(ii).zerr > 30)=NaN;
end
save([data_path '/cbathy.mat'], 'cbathy')


%% Create composite bathymetry
% run /Volumes/LANGE_Passport/UAV_video-based_estimates_of_nearshore_bathymetry/CODES/bathy_from_UAV.m