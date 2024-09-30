%% run_cBathy
% run_cBathy runs cBathy 2.0 Steps 1 and 2 (no Kalman filtering) based off of Holman and Bergsma 2022
%% Description
%
%   Args:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%           day_files (structure) : folders of the days to process - requires day_files.folder and day_files.name
%           camera_type (string) : 'ARGUS' or 'UAV' depending on processing
%           flights (structure) : for camea_type = 'UAV' : folders of the flights to process - requires flights.folder and flights.name
%           cam_num (double) : for camea_type = 'ARGUS' : number of cameras to loop through
%           Products (structure) : Data products
%                       type (string) : 'Grid', 'xTransect', 'yTransect'
%                       frameRate (double) : frame rate of product (Hz)
%                       lat (double) : latitude of origin grid
%                       lon (double): longitude of origin grid
%                       angle (double): shorenormal angle of origid grid (degrees CW from North)
%                       xlim (double): [1 x 2] cross-shore limits of grid (+ is offshore of origin) (m)
%                       ylim (double) : [1 x 2] along-shore limits of grid (+ is to the right of origin looking offshore) (m)
%                       dx (double) : Cross-shore resolution (m)
%                       dy (double) : Along-shore resolution (m)
%                       x (double): Cross-shore distance from origin (+ is offshore of origin) (m)
%                       y (double): Along-shore distance from origin (+ is to the right of the origin looking offshore) (m)
%                       z (double) : Elevation - can be empty or array of DEM values (NAVD88 m)
%                       tide (double) : Tide level (NAVD88 m)
%                       t (datetime array) : [1 x m] datetime of images at given extraction rates in UTC
%                       localX (double) : [y_length x x_length] x coordinates in locally-defined coordinate system (+x is offshore, m)
%                       localY (double) : [y_length x x_length] y coordinates in locally-defined coordinate system (+y is right of origin, m)
%                       localZ (double) : [y_length x x_length] z coordinates in locally-defined coordinate system
%                       Eastings (double) : [y x x] Eastings coordinates (m)
%                       Northings (double) : [y x x] Northings coordinates (m)
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
%
% 
%   Returns:
%           bathy (structure) : cBathy output after Step 2
%                       params (structure) : cBathy parameters
%                       epoch (string) : epoch time of image
%                       sName (string) : name 'YYYYMMDD_Location_Flight/Cam'
%                       ver (double) : 2 - cBathy version number
%                       matVer (string) : Matlab version
%                       tide (double) : tide elevation
%                       xm (array) : cross-shore locations in m from origin
%                       ym (array) : along-shore locations in m from origin
%                       timex (array) : [y_length x x_length] time-averaged image
%                       fDependent (structure) : cBathy Step 1
%                       fCombined (structure) : cBathy Step 2
%                                   h (array) : [y_length x x_length] cBathy depth estimate
%                                   hErr (array) : [y_length x x_length] cBathy error estimates
%                       runningAverage (structure) : 
%                       bright (array) : [y_length x x_length] bright image
%                       dark (array) : [y_length x x_length] dark image
%                       cpuTime (double) : cpu processing time
%                       coords (structure) : 
%                                   Xo (array) :  [y_length x x_length] cross-shore location grid in m from origin
%                                   Eout (array) :  [y_length x x_length] cross-shore location in Eastings
%                                   Yo (array) :  [y_length x x_length] cross-shore location grid in m from origin
%                                   Nout (array) :  [y_length x x_length] cross-shore location in Northings
%
%
%% Function Dependenies
% cBathy 2.0 code directory
%
%% Citation Info
% github.com/AthinaLange/CoastalLens
% Jul 2024;

%% Data
if ~exist('camera_type', 'var')
    camera_type = questdlg('UAV or ARGUS?', 'UAV or ARGUS?', 'UAV', 'ARGUS', 'UAV');
end
switch camera_type
    case 'UAV'
        if ~exist('global_dir', 'var') || ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
            disp('Missing global_dir and day_files. Please load in processing_run_DD_Month_YYYY.mat that has the day folders that you would like to process. ')
            [temp_file, temp_file_path] = uigetfile(pwd, 'processing_run_.mat file');
            load(fullfile(temp_file_path, temp_file)); clear temp_file*
            assert(isfolder(global_dir),['Error (run_cBathy): ' global_dir 'doesn''t exist.']);

            if ~exist('global_dir', 'var')
                disp('Please select the global directory.')
                global_dir = uigetdir('.', 'UAV Rectification');
                cd(global_dir)
            end
            if ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
                disp('Choose DATA folder.')
                disp('For Athina: DATA')
                data_dir = uigetdir('.', 'DATA Folder');

                day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
                [ind_datafiles,~] = listdlg('ListString',{day_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'}, 'ListSize', [500 300]);
                day_files = day_files(ind_datafiles);
            end
        end % if exist('global_dir', 'var')

        % check that needed files exist
        for dd = 1:length(day_files)
            assert(isfile(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat')),['Error (run_cBathy): ' fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat') ' doesn''t exist.']);
        end

    case 'ARGUS'

        if ~exist('global_dir', 'var')
            disp('Please select the global directory.')
            global_dir = uigetdir('.', 'CoastalLens_ARGUS');
            cd(global_dir)
        end
        if ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
            disp('Choose DATA folder.')
            data_dir = uigetdir('.', 'DATA Folder');

            % Load in all days that need to be processed.
            day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
            day_files(contains({day_files.name}, 'GCP'))=[]; day_files(contains({day_files.name}, 'Make_products'))=[];
            day_files(contains({day_files.name}, 'Processed_data'))=[];day_files(contains({day_files.name}, 'Products'))=[];

            processed_files = dir(fullfile(data_dir, 'Processed_data')); processed_files([processed_files.isdir] == 1)=[];
            processed_files(~contains({processed_files.name}, 'Products'))=[];
            % if file already processed - don't reprocess
            if ~isempty(processed_files)
                for ii = length(day_files):-1:1
                    if contains([processed_files.name], day_files(ii).name)
                        day_files(ii) = [];
                    end
                end
            end
        end
end % switch camera_type

%%
disp('Please choose cBathy repository.')
cbathy_dir = uigetdir('.', ['Choose cBathy (repository) folder - ''cBathy (v2.0)''.']);
addpath(genpath(cbathy_dir))
%%
close all
switch camera_type
    case 'ARGUS'
        disp('How many cameras are you processing?')
        cam_num = str2double(string(inputdlg('How many cameras?')));
end

for  dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files cam_num camera_type
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    switch camera_type
        case 'UAV'
	    
	    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'), 'flights')
	    if ~exist('flights', 'var')
		flights = dir(fullfile(day_files(dd).folder, day_files(dd).name)); flights([flights.isdir]==0)=[];
	        flights(contains({flights.name}, '.'))=[]; flights(contains({flights.name}, 'GCP'))=[];
	    end
            assert(exist('flights', 'var'), 'Error (run_cBathy): flights must exist and be stored in ''day_config_file.mat''.')
            assert(isa(flights, 'struct'), 'Error (run_cBathy): flights must be a structure.')
            assert((isfield(flights, 'folder') && isfield(flights, 'name')), 'Error (run_cBathy): flights must have fields .folder and .name.')
    end
       
    % repeat for each flight
    switch camera_type
        case 'UAV'
            loop_num = length(flights);
        case 'ARGUS'
            loop_num = cam_num;
    end
    for ff = 1:loop_num
    switch camera_type
        case 'UAV'
            odir = fullfile(flights(ff).folder, flights(ff).name);
            oname = [day_files(dd).name '_' flights(ff).name];
            load(fullfile(odir, 'Processed_data', [oname '_Products.mat']), 'Products')
        case 'ARGUS'
            odir = fullfile(data_dir);
            oname = strcat('ARGUS2_Cam', string(ff),'_', day_files(dd).name);
            load(fullfile(data_dir, 'Processed_data', strcat(oname, '_Products')), 'Products')
    end
        disp(oname)
        cd(odir)

        assert(isa(Products, 'struct'), 'Error (run_cBathy): Products must be a stucture as defined in user_input_products.')
        assert((isfield(Products, 'type') && isfield(Products, 'frameRate')), 'Error (run_cBathy): Products must be a stucture as defined in user_input_products.')

        ids_grid = find(ismember(string({Products.type}), 'Grid'));
        for pp = ids_grid % repeat for all grids
            %% run cBathy 2.0
            for viewId = 1:size(Products(pp).Irgb_2d,1)
                Igray(:,:,viewId) = im2gray(squeeze(Products(pp).Irgb_2d(viewId, :,:,:)));
            end
            % Remove Nans
            [r c tt]=size(Igray);
            for k=1:r
                for j=1:c
                    bind =find(isnan(Igray(k,j,:))==1);
                    gind =find(isnan(Igray(k,j,:))==0);
                    Igray(k,j,bind)=nanmean(Igray(k,j,gind));
                end
            end
            if Products(pp).angle < 180 % East Coast
                Xout = Products(pp).localX;
                Yout = Products(pp).localY;
            elseif Products(pp).angle >180 % West Coast
                Xout=-(Products(pp).localX.*cosd(180)+Products(pp).localY.*sind(180));
                Yout=-(Products(pp).localY.*cosd(180)-Products(pp).localX.*sind(180));
            end % if Products(pp).angle < 180 % East Coast
            Zout = Products(pp).localZ;

            %Demo Plot
            figure(1);clf
            subplot(121)
            pcolor(Products(pp).localX,Products(pp).localY,Igray(:,:,1))
            shading flat
            set(gca, 'XDir', 'reverse')
            title('Original localX/Y')
            subplot(122)
            pcolor(Xout,Yout,Igray(:,:,1))
            shading flat
            title('Rotated localX/Y - waves coming from east')

            xyz=[Xout(:) Yout(:) Zout(:)];

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

            %% Loading CIRN data
            clearvars -except dd *_dir user_email day_files ff pp ids_grid Products xyz data odir oname flights cam_num camera_type

            % Fill in cam requirement
            cam=xyz.*0+1;

            % Get into Epoch time
            epoch=posixtime(Products(pp).t);
            %% cBathy Parameters
            % cBathyTideTorrey pulls from NOAA SIO tide gauge. If tide different, use
            % different function

            %%% Site-specific Inputs
            params.stationStr = oname;
            params.dxm = Products(pp).dx;%5;                    % analysis domain spacing in x
            params.dym = Products(pp).dy;%10;                    % analysis domain spacing in y
            params.xyMinMax = [min(xyz(:,1)) max(xyz(:,1)) min(xyz(:,2)) max(xyz(:,2))];   % min, max of x, then y
            % default to [] for cBathy to choose
            params.tideFunction = 'cBathyTideneutral';  % tide level function for evel

            %%%%%%%   Power user settings from here down   %%%%%%%
            params.MINDEPTH = 0.25;             % for initialization and final QC
            params.MAXDEPTH = 20;             % for initialization and final QC
            params.QTOL = 0.5;                  % reject skill below this in csm
            params.minLam = 12;                 % min normalized eigenvalue to proceed
            params.Lx = 25;%3*params.dxm;           % tomographic domain smoothing
            params.Ly = 50;%3*params.dym;           %
            params.kappa0 = 2;                  % increase in smoothing at outer xm
            params.DECIMATE = 1;                % decimate pixels to reduce work load.
            params.maxNPix = 80;                % max num pixels per tile (decimate excess)
            params.minValsForBathyEst = 4;

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
            params.nlinfit=1;
            %% Run cBathy

            bathy.params = params;
            bathy.epoch  = num2str(epoch(1));
            bathy.sName  = oname;

            bathy = analyzeBathyCollect(xyz, epoch, (data), cam, bathy)
            figure
            bathy.params.debug.production=1;
            plotBathyCollect(bathy)
            sgtitle([oname])
            %% Kalman step can be implemented here.
            
            %%
            [Xo Yo]=meshgrid(bathy.xm,bathy.ym);

            if Products(pp).angle < 180 % East Coast

            elseif Products(pp).angle > 180 % West Coast
                Xo=-(Xo.*cosd(180)+Yo.*sind(180));
                Yo=-(Yo.*cosd(180)-Xo.*sind(180));
                bathy.fCombined.h = fliplr(bathy.fCombined.h);
                bathy.fCombined.hErr = fliplr(bathy.fCombined.hErr);
            end % if Products(pp).angle < 180 % East Coast

            bathy.coords.Xo = Xo; bathy.coords.Eout = Products(pp).Eastings;
            bathy.coords.Yo = Yo; bathy.coords.Nout = Products(pp).Northings;

            tide = Products(pp).tide;
            bathy.fDependent.hTemp = bathy.fDependent.hTemp + tide;
	        bathy.fCombined.h = bathy.fCombined.h + tide;
	        bathy.tide = tide;

            save(fullfile(odir, 'Processed_data', strcat(oname, '_cBathy')),'bathy', '-v7.3')

        end % for pp = ids_grid % repeat for all grids

        if exist('user_email', 'var')
            try
                sendmail(user_email{2}, [oname '- Rectifying Products DONE'])
            end
        end % if exist('user_email', 'var')
    end %  for ff = 1 : length(flights)
end % for  dd = 1 : length(day_files)
close all
cd(global_dir)
