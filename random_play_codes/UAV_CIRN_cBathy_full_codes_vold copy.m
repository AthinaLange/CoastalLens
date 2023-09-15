%% UAV CIRN & timestack Workflow

aa=split(data_dir,'/');
stationStr = char(aa(end))
close all 
clearvars -except stationStr *_dir

%% ========================================================================
%                                   CIRN
% =========================================================================

%% Loop through all flights from day - clicking step
for nn = 1:num_flights
    %%
    clearvars -except *dir video_path flights num_flights stationStr nn
    nn
    video_path = fullfile(data_dir,flights(nn,:))
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = [ stationStr '_' filename];
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];

    %% E - Choosing SCP
    % click on scp point, give it a number (matches the number in gps.txt), 
    % choose radius of pixel frame to look around the reprojected coordinate 
    % (typically between 15-8 for our targets), then set the intensity 
    % threshold (make sure only the scp point shows up - code will take the 
    % average location of all the points above the threshold)
    % scp's do NOT need to be the same as gcp (but they do need to remain
    % visible f1or the whole sequence of images)
    idir = [odir '/images_10Hz/'];
    imageDirectory = idir;
    L=sort(split(string(ls(imageDirectory)))); L=L(2:end); % Athina: changes
    imagePath= append(imageDirectory,L(1));
    
    B_gcpSelection
    save(fullfile(odir, 'Processed_data', [oname '_gcpUVdInitial']),'gcp')
    
    %% C - Choosing GCP : confirm gcp used
    % will pull gcp gps.txt file into subdirectory
    %                            -> update as new flights come in
    % click on choosen gcp from B1
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
        form = char(C.FileName);
        form = string(form(:,end-2:end));
        mov_id = find(form == 'MOV');
        jpg_id = find(form == 'JPG');if length(jpg_id)>1;jpg_id = jpg_id(1);end; if length(jpg_id)==0; jpg_id = mov_id(1);end

        extrinsicsInitialGuess= [UTMEasting UTMNorthing C.AbsoluteAltitude(jpg_id)-zgeoid_offset deg2rad(C.CameraYaw(mov_id(1))+360) deg2rad(C.CameraPitch(mov_id(1))+90) deg2rad(C.CameraRoll(mov_id(1)))]; % [ x y z azimuth tilt swing]
        extrinsicsKnownsFlag= [1 1 0 0 0 0];  % [ x y z azimuth tilt swing]
    
        C_singleExtrinsicSolution
        extrinsics(3)=ceil(C.RelativeAltitude(jpg_id))-zgeoid_offset;
        save(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'initialCamSolutionMeta','extrinsics','intrinsics')
    
 %%
    ioeopath = fullfile(odir, 'Processed_data', [oname '_IOEOInitial' ]);
    
    D_gridGenExampleRect
    
    ioeopath = fullfile(odir, 'Processed_data', [oname '_IOEOInitial' ]);
    
    D_gridGenExampleRect
    %%
    
    cd('..')
    clearvars -except num_flights flights *_dir stationStr nn

end

%% F : Loop through all flights from day - processing step
for nn = 4%:num_flights

    video_path = fullfile(data_dir, flights(nn,:))
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = [stationStr '_' filename];
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    
    %% Drone Coordinates
    load(fullfile(data_dir, filename, 'Processed_data', 'C'))

    %% F - Extrinsics : confirm scp used 2Hz
    %click on all your chosen scp
    idir = fullfile(odir,  'images_10Hz');
    
    ab = importdata(fullfile(odir, 'gps_northings.txt')); ab = [ab(:,1) ab(:,4)];
    load(fullfile(odir, 'Processed_data', [oname '_scpUVdInitial' ]))
    for ss = 1:length(scp); ind_scp(ss) = scp(ss).num; end
    scpz = ab(ind_scp,:);
    
    to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles');
    to.TimeZone = 'UTC'
    to = datenum(to);
    %  Enter the dt in seconds of the collect. If not known, leave as {}. Under
    %  t, images will just be numbered 1,2,3,4.
    frameRate = 2;
    dts= 1./frameRate; %Seconds
    %
    L=sort(split(string(ls(idir)))); L=L(2:5:end); % Athina: changes
    F_variableExtrinsicSolutions
    savefig(fullfile('Processed_data', [oname '_Extrinsics_2Hz']))
    
    %% F - Extrinsics : confirm scp used 10Hz
    %click on all your chosen scp
    idir = fullfile(odir,  'images_10Hz');
    
    ab = importdata(fullfile(odir, 'gps_northings.txt')); ab = [ab(:,1) ab(:,4)];
    load(fullfile(odir, 'Processed_data', [oname '_scpUVdInitial' ]))
    for ss = 1:length(scp); ind_scp(ss) = scp(ss).num; end
    scpz = ab(ind_scp,:);
    
    to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles');
    to.TimeZone = 'UTC'
    to = datenum(to);
    %  Enter the dt in seconds of the collect. If not known, leave as {}. Under
    %  t, images will just be numbered 1,2,3,4.
    frameRate = 10;
    dts= 1./frameRate; %Seconds
    %
    L=sort(split(string(ls(idir)))); L=L(2:end); % Athina: changes
    F_variableExtrinsicSolutions

    savefig(fullfile('Processed_data', [oname '_Extrinsics_10Hz']))
    %%
    cd('..')
    clearvars -except num_flights flights *_dir stationStr jpg_id
end

%% G2 : Loop through all flights from day - processing step
for nn = 1:num_flights
    close all
    video_path = [data_dir '/' flights(nn,:)]
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = [stationStr '_' filename];
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    
    %% Drone Coordinates
    load(fullfile(data_dir, filename, 'Processed_data', 'C'))
    %% G1 - image Products
    % computes the pixel intensity time series for every grid point
    idir = fullfile(odir,  'images_10Hz');
    frameRate = 2;
    
    imageDirectory = idir;
    
    ioeopath = fullfile(odir, 'Processed_data', [oname '_' char(string(frameRate)) '_IOEOVariable.mat']);
    gname = [oname '_NAVD88_' char(string(frameRate)) 'Hz.mat'];
    
    clear pixInst
    localFlag=1
    G1_imageProducts
    %% G2 - getting pixel intensity Grid
    % computes the pixel intensity time series for every grid point
    idir = fullfile(odir,  'images_10Hz');
    frameRate = 2
    
    imageDirectory = idir;
    
    ioeopath = fullfile(odir, 'Processed_data', [oname '_' char(string(frameRate)) '_IOEOVariable.mat']);
    gname = [oname '_NAVD88_' char(string(frameRate)) 'Hz.mat'];
    load(fullfile(odir, 'Processed_data', ['GRID_' gname]), 'localX', 'localY')
    
    clear pixInst
    localFlag=1
    
    pixInst.type='Grid';
    pixInst.dx = 5; % 5
    pixInst.dy = 5; % 5
    pixInst.xlim = [localX(1) localX(end)];
    pixInst.ylim = [localY(1) localY(end)];
    pixInst.z={}; % Leave empty if you would like it interpolated from input
    
    
    % Z grid or zFixedCam. If entered here it is assumed constant
    % across domain and in time.
    L=sort(split(string(ls(imageDirectory)))); L=L(2:5:end); % Athina: changes
    imagePath = append(imageDirectory,L(1));
    
    G2_2Hz_pixelInstruments
    clear pixInst
%% G2 - getting pixel intensity Transects
    % computes the pixel intensity time series for every grid point
%     idir = fullfile(odir, 'images_10Hz');
%     frameRate = 10
%     ioeopath = fullfile(odir, 'Processed_data', [oname '_' char(string(frameRate)) '_IOEOVariable.mat']);
%     gname = [oname '_NAVD88_' char(string(frameRate)) 'Hz.mat'];
%     
%     clear pixInst
%     localFlag=1
%     
%     locations = string({'Torrey', 'Cardiff', 'SIO', 'Carmel', 'Pajaro'});
%     grid_num = find(locations == stationStr(10:end));
%     
%     if grid_num == 1 % Torrey
%         for ii = 1:29
%             pixInst(ii).y = -300+20*(ii-1)
%             pixInst(ii).type='xTransect';
%             pixInst(ii).dx =.1;
%             pixInst(ii).xlim = [-500 0];
%             pixInst(ii).z={}; % Leave empty if you would like it interpolated from input
%         end
%     elseif grid_num == 2 % Cardiff
%         for ii = 1:18
%             pixInst(ii).y = -220+20*(ii-1)
%             pixInst(ii).type='xTransect';
%             pixInst(ii).dx =.1;
%             pixInst(ii).xlim = [-500 0];
%             pixInst(ii).z={}; % Leave empty if you would like it interpolated from input
%         end
%     elseif grid_num == 3 % SIO
%         for ii = 1:12
%             pixInst(ii).y = -40+20*(ii-1)
%             pixInst(ii).type='xTransect';
%             pixInst(ii).dx =.1;
%             pixInst(ii).xlim = [-500 0];
%             pixInst(ii).z={}; % Leave empty if you would like it interpolated from input
%         end
%     end
%     
%     % Z grid or zFixedCam. If entered here it is assumed constant
%     % across domain and in time.
%     imageDirectory = idir;
%     L=sort(split(string(ls(imageDirectory)))); L=L(2:end); % Athina: changes
%     imagePath= append(imageDirectory,L(1));
% 
%     G2_pixelInstruments
%     %load(['Processed_data/' stackName '_10_pixInst.mat'], 'pixInst')
%     
%     if grid_num == 1
%         imwrite(pixInst(1).Irgb,['Processed_data/' stackName '_579.png'])
%         imwrite(pixInst(2).Irgb,['Processed_data/' stackName '_579.2.png'])
%         imwrite(pixInst(3).Irgb,['Processed_data/' stackName '_579.4.png'])
%         imwrite(pixInst(4).Irgb,['Processed_data/' stackName '_579.6.png'])
%         imwrite(pixInst(5).Irgb,['Processed_data/' stackName '_579.8.png'])
%         imwrite(pixInst(6).Irgb,['Processed_data/' stackName '_580.png'])
%         imwrite(pixInst(7).Irgb,['Processed_data/' stackName '_580.2.png'])
%         imwrite(pixInst(8).Irgb,['Processed_data/' stackName '_580.4.png'])
%         imwrite(pixInst(9).Irgb,['Processed_data/' stackName '_580.6.png'])
%         imwrite(pixInst(10).Irgb,['Processed_data/' stackName '_580.8.png'])
%         imwrite(pixInst(11).Irgb,['Processed_data/' stackName '_581.png'])
%         imwrite(pixInst(12).Irgb,['Processed_data/' stackName '_581.2.png'])
%         imwrite(pixInst(13).Irgb,['Processed_data/' stackName '_581.4.png'])
%         imwrite(pixInst(14).Irgb,['Processed_data/' stackName '_581.6.png'])
%         imwrite(pixInst(15).Irgb,['Processed_data/' stackName '_581.8.png'])
%         imwrite(pixInst(16).Irgb,['Processed_data/' stackName '_582.png'])
%         imwrite(pixInst(17).Irgb,['Processed_data/' stackName '_582.2.png'])
%         imwrite(pixInst(18).Irgb,['Processed_data/' stackName '_582.4.png'])
%         imwrite(pixInst(19).Irgb,['Processed_data/' stackName '_582.6.png'])
%         imwrite(pixInst(20).Irgb,['Processed_data/' stackName '_582.8.png'])
%         imwrite(pixInst(21).Irgb,['Processed_data/' stackName '_583.png'])
%         imwrite(pixInst(22).Irgb,['Processed_data/' stackName '_583.2.png'])
%         imwrite(pixInst(23).Irgb,['Processed_data/' stackName '_583.4.png'])
%         imwrite(pixInst(24).Irgb,['Processed_data/' stackName '_583.6.png'])
%         imwrite(pixInst(25).Irgb,['Processed_data/' stackName '_583.8.png'])
%         imwrite(pixInst(26).Irgb,['Processed_data/' stackName '_584.png'])
%         imwrite(pixInst(27).Irgb,['Processed_data/' stackName '_584.2.png'])
%         imwrite(pixInst(28).Irgb,['Processed_data/' stackName '_584.4.png'])
%         imwrite(pixInst(29).Irgb,['Processed_data/' stackName '_584.6.png'])
%     elseif grid_num == 2
%         imwrite(pixInst(1).Irgb,['Processed_data/' stackName '_666.8.png'])
%         imwrite(pixInst(2).Irgb,['Processed_data/' stackName '_667.png'])
%         imwrite(pixInst(3).Irgb,['Processed_data/' stackName '_667.2.png'])
%         imwrite(pixInst(4).Irgb,['Processed_data/' stackName '_667.4.png'])
%         imwrite(pixInst(5).Irgb,['Processed_data/' stackName '_667.6.png'])
%         imwrite(pixInst(6).Irgb,['Processed_data/' stackName '_667.8.png'])
%         imwrite(pixInst(7).Irgb,['Processed_data/' stackName '_668.png'])
%         imwrite(pixInst(8).Irgb,['Processed_data/' stackName '_668.2.png'])
%         imwrite(pixInst(9).Irgb,['Processed_data/' stackName '_668.4.png'])
%         imwrite(pixInst(10).Irgb,['Processed_data/' stackName '_668.6.png'])
%         imwrite(pixInst(11).Irgb,['Processed_data/' stackName '_668.8.png'])
%         imwrite(pixInst(12).Irgb,['Processed_data/' stackName '_669.png'])
%         imwrite(pixInst(13).Irgb,['Processed_data/' stackName '_669.2.png'])
%         imwrite(pixInst(14).Irgb,['Processed_data/' stackName '_669.4.png'])
%         imwrite(pixInst(15).Irgb,['Processed_data/' stackName '_669.6.png'])
%         imwrite(pixInst(16).Irgb,['Processed_data/' stackName '_669.8.png'])
%         imwrite(pixInst(17).Irgb,['Processed_data/' stackName '_670.png'])
%         imwrite(pixInst(18).Irgb,['Processed_data/' stackName '_670.2.png'])
%     elseif grid_num == 3
%         imwrite(pixInst(1).Irgb,['Processed_data/' stackName '_512.6.png'])
%         imwrite(pixInst(2).Irgb,['Processed_data/' stackName '_512.8.png'])
%         imwrite(pixInst(3).Irgb,['Processed_data/' stackName '_513.png'])
%         imwrite(pixInst(4).Irgb,['Processed_data/' stackName '_513.2.png'])
%         imwrite(pixInst(5).Irgb,['Processed_data/' stackName '_513.4.png'])
%         imwrite(pixInst(6).Irgb,['Processed_data/' stackName '_513.6.png'])
%         imwrite(pixInst(7).Irgb,['Processed_data/' stackName '_513.8.png'])
%         imwrite(pixInst(8).Irgb,['Processed_data/' stackName '_514.png'])
%         imwrite(pixInst(9).Irgb,['Processed_data/' stackName '_514.2.png'])
%         imwrite(pixInst(10).Irgb,['Processed_data/' stackName '_514.4.png'])
%         imwrite(pixInst(11).Irgb,['Processed_data/' stackName '_514.6.png'])
%         imwrite(pixInst(12).Irgb,['Processed_data/' stackName '_514.8.png'])
%     
%     end
    % %%
    % 
    % save('Processed_data/CIRN', '-v7.3')
    clearvars -except num_flights flights *_dir stationStr jpg_id nn
    cd('..')
end

%% ========================================================================
%                               cBathy 2.0
% =========================================================================
%%
loadMOPdata

%% Flip CIRN for cBathy
for nn = 1:num_flights
    
    video_path = [data_dir '/' flights(nn,:)]
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
    load(fullfile('Processed_data', [stackName '_2Hz_pixInst.mat']))
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
    [ Xout Yout]= localTransformPoints([pixInst(1).X(end,end) pixInst(1).Y(end,end) ],180,1,pixInst(1).X,pixInst(1).Y);
    
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
    load('Processed_data/C')
    to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles');
    to.TimeZone = 'UTC';
    [~, nearestIdx] = min(abs(timeseries_mop - to));
    mop_data.fq = Fq_mop;
    mop_data.Ed = Ed_mop(:, nearestIdx);
    
    save(fullfile(odir, 'Processed_data', [stackName '.mat']), 'xyz', 'data', 't','pixInst', 'flights', 'num_flights', 'mop_data', '-v7.3')
    cd('..')
end

%%
for nn = 1:num_flights
    video_path = fullfile(data_dir, flights(nn,:))
    cd(video_path)
    aa=split(pwd,'/');
    filename = char(aa(end))
    
    odir = pwd;
    oname = stationStr;
    csvname = [filename '.csv'];
    stackName = [ stationStr '_' filename];
    
% Loading CIRN data
    % remove all unnecessary loaded variables
    % load previously saved cBathy input data
   % addpath(genpath('/Volumes/LANGE_Passport/DRONE_PROCESSING_CODES/cBathy_2.0'))
    
    clearvars -except *_dir nn flights num_flights odir oname stackName stationStr filename 
    load(fullfile(odir, 'Processed_data', [stackName '.mat']))
    
    % Fill in cam requirement
    cam=xyz.*0+1;
    % Get into Epoch time
    epoch=(t-datenum(1970,1,1))*24*3600;
% CBathy Parameters
    % cBathyTideTorrey pulls from NOAA SIO tide gauge. If tide different, use
    % different function
    
    %%% Site-specific Inputs
    params.stationStr = stationStr;
    params.dxm = 5;                    % analysis domain spacing in x
    params.dym = 20;                   % analysis domain spacing in y
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
    params.Lx = 25;%5*params.dxm;           % tomographic domain smoothing
    params.Ly = 100;%5*params.dym;           % 
    params.kappa0 = 3;                  % increase in smoothing at outer xm
    params.DECIMATE = 1;                % decimate pixels to reduce work load.
    params.maxNPix = 80;                % max num pixels per tile (decimate excess)
    params.minValsForBathyEst = 4;      % need this many pixels to solve
    params.shortLengthNFreqs = 4;       % need this many for coherence sorting
                                        % versus magnitude shorting
    
    % f-domain etc.
    params.fB = [0.055: 1/200 :0.25];% [1/18: 1/50: 1/4];%[0.065: 1/50: 0.16];%		% frequencies for analysis (~40 dof)
    params.nKeep = 4;                   % number of frequencies to keep
    
    % debugging options
    params.debug.production = 1;                % if 1, no debug plots
    params.debug.DOPLOTSTACKANDPHASEMAPS = 1;  % top level debug of phase
    params.debug.DOSHOWPROGRESS = 1;		  % show progress of tiles
    params.debug.DOPLOTPHASETILE = 1;		  % observed and EOF results per pt
    params.debug.TRANSECTX = 375;		  % for plotStacksAndPhaseMaps
    params.debug.TRANSECTY = 700;		  % for plotStacksAndPhaseMaps
    
    % default offshore wave angle.  For search seeds.
    params.offshoreRadCCWFromx = 0;
    params.nlinfit=1; % flag, 0 = use LMFnlsq.m to do non-linear fitting
% Run Cbathy
     
    bathy.params = params;
    bathy.epoch  = num2str(epoch(1));
    bathy.sName  = stackName;
    
    bathy = analyzeBathyCollect(xyz, epoch, (data), cam, bathy);
    close all
    figure
    plotBathyCollect(bathy)
    sgtitle([[stationStr(1:8) ' - ' stationStr(10:end)] string(stackName(end-1:end))])
    if isfield(bathy, 'version')
        version = char(string(bathy.version));
    elseif isfield(bathy, 'ver')
        version = char(string(bathy.ver));
    end
    savefig(fullfile('Processed_data', [oname '_bathy_v' version '.fig']))
    close all
    % Rotate back to West Coast
    [Xo Yo]=meshgrid(bathy.xm,bathy.ym);
    [Eout Nout]= localTransformPoints([pixInst(1).X(end,end) pixInst(1).Y(end,end) ],180,0,Xo,Yo);
    bathy.coords.Xo = Xo; bathy.coords.Eout = Eout;
    bathy.coords.Yo = Yo; bathy.coords.Nout = Nout;
    save(fullfile(odir, 'Processed_data', ['cBathy_' stackName '_v' version '.mat']), '-v7.3')
    save(fullfile(odir, 'Processed_data', ['cBathy_Results_' stackName '_v' version '.mat']), 'bathy', '-v7.3')
    
    cd('..')
end
%%



