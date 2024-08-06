%% run_cBathyCT
% run_cBathyCT returns cBathyCT output based off Lange et al. 2023
%
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
%                       lat (double) : latitude of origin grid
%                       lon (double): longitude of origin grid
%                       xlim (double): [1 x 2] cross-shore limits of grid (+ is offshore of origin) (m)
%                       ylim (double) : [1 x 2] along-shore limits of grid (+ is to the right of origin looking offshore) (m)
%                       dx (double) : Cross-shore resolution (m)
%                       dy (double) : Along-shore resolution (m)
%                       x (double): Cross-shore distance from origin (+ is offshore of origin) (m)
%                       y (double): Along-shore distance from origin (+ is to the right of the origin looking offshore) (m)
%                       z (double) : Elevation - can be empty or array of DEM values (NAVD88 m)
%                       tide (double) : Tide level (NAVD88 m)%                       Eastings (double) : [y x x] Eastings coordinates (m)
%                       Northings (double) : [y x x] Northings coordinates (m)
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
%           bathy (structure) : cBathy output after Step 2
%                       fCombined (structure) : cBathy Step 2
%                                   h (array) : [y_length x x_length] cBathy depth estimate
%                                   hErr (array) : [y_length x x_length] cBathy error estimates
%                       coords (structure) :
%                                   Eout (array) :  [y_length x x_length] cross-shore location in Eastings
%                                   Nout (array) :  [y_length x x_length] cross-shore location in Northings
%           DEM (structure) : Digital Elevation Map Data
%                       time (datetime) : date of jumbo survey used
%                       type (cell array) : Survey type for each transect
%                       MOP (cell array) : Mop number of each x transect
%                       X (array): [mop_length x cross-shore length] - Eastings
%                       Y (array): [mop_length x cross-shore length] - Northings
%                       Z (array): [mop_length x cross-shore length] - Elevation (NAVD88m)
%
%
%   Returns:
%           cBathyCT (structure) : cBathyCT results
%                       date (string) : date of product (YYYYMMDD)
%                       Iocation (string) : location name - from filename
%                       flight / cam (double) : flight number (for UAV) or camera number (for ARGUS)
%                       mop (double) : mop number
%                       x10 (array) : [0:0.1:500], 0.1m resolution - all elevation values interpolated to this x array
%                       survey (structure) :
%                                   z (array) : [1 x length(x10)] elevation pulled from survey DEM on MOP line
%                       cbathy (structure):
%                                   z (array) : cBathy direct output on given transect
%                                   zerr (array) : cBathy hErr
%                                   cbathy_hErr (array) : cBathy with hErr > 0.5m region interpolated over
%                                   cbathy_gamma (array) : cBathy with breaking region removed for given variable gamma(x)
%                       tide (double) : tide level - pulled from Products tide level
%                       min_tide (double) : minimum tide level of day - pulled from DEM - assuming survey taken at daily low tide
%                       crests (structure) :
%                                   t (array) : time for wave tracks (sec)
%                                   x (array) : cross-shore location for wave tracks (m) (0 is offshore, 500 is onshore)
%                                   c (array) : phase speed of wave tracks (m/s) - interpolated to x10
%                       bp (array) : breakpoint location for each crest
%                       xshift (double) : index (for x10) of cross-shore shift required to match subaerial survey with subaqueous bathymetry - should be small if using DEM
%                       h_avg (structure) :
%                                   lin (array) : linear crest-tracking c = sqrt(gh)
%                                   nlin (array) : nonlinear crest-tracking  = sqrt(gh(1+0.42))
%                                   bp (array) : breakpoint transition crest-tracking c = sqrt(gh(1+gamma(x)))
%                       gamma (array) : [ x ] transition between 0 and 0.42 for each wave track 0 interpolated to x10
%                       gamma_mean (array) : [1 x length(x10)] mean of all step function gammas
%                       composite (structure) : constructed topobathy products with subaerial survey +
%                                   cbathy_hErr (array) : cBathy with hErr < 0.5m
%                                   cbathy_gamma (array) : cBathy with breaking region removed
%                                   cbathy_nlin (array) : cbathy_gamma with gamma(x) correction
%                                   cbathyCT (array) : breakpoint transition crest-tracking surfzone bathymetry and cBathy offshore
%                       lims (array) : [1 x 3] index of [1st BP valid onshore point, onshore cuttoff of breaking, offshore cutoff of breaking]
%                       Error (structure) :
%                                   RMSE (root-mean-square error),
%                                   Skill
%                                   Bias
%
%
%% Function Dependenies
% find_crests
% breakpt_calculator
% pixel_res
% func_cbathyCT
%
% requires DEM
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
disp('Please choose Timestack Prediction repository.')
disp('Raw timestack should be in folder "Timestack".')
disp('Wave crest predictions should be in folder "Prediction".')
timestack_dir = uigetdir('.', 'Choose Timestack Prediction (repository) folder.');
timestack_png = imageDatastore(fullfile(timestack_dir, 'Timestacks'));
prediction_png = imageDatastore(fullfile(timestack_dir, 'Prediction'));


disp('Please choose DEM topo / survey file.')
disp('This is required for the subaerial beach survey. The format should be the same as the cBathy grid.')
[temp_file, temp_file_path] = uigetfile(pwd, 'DEM file');
load(fullfile(temp_file_path, temp_file)); clear temp_file*


%%
close all
switch camera_type
    case 'ARGUS'
        disp('How many cameras are you processing?')
        cam_num = str2double(string(inputdlg('How many cameras?')));
end

for  dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files DEM* *_png cam_num camera_type
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    switch camera_type
        case 'UAV'
            load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'), 'flights')
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
        clear cBathyCT CT
        close all
        switch camera_type
            case 'UAV'
                odir = fullfile(flights(ff).folder, flights(ff).name);
                oname = [day_files(dd).name '_' flights(ff).name];
                load(fullfile(odir, 'Processed_data', [oname '_Products.mat']), 'Products')

                ab = split(oname, '_');
                date = datetime(str2num(ab{1}), 'ConvertFrom', 'yyyyMMdd');
                location = ab{2};
                flight = str2num(ab{3});

            case 'ARGUS'
                odir = fullfile(data_dir);
                oname = strcat('ARGUS2_Cam', string(ff),'_', day_files(dd).name);
                load(fullfile(data_dir, 'Processed_data', strcat(oname, '_Products')), 'Products')

                ab = split(oname, '_');
                date = datetime(str2num(ab{3}), 'ConvertFrom', 'yyyyMMdd');
                location = ab{4};
                cam = ff;

        end
        disp(oname)
        cd(odir)

        [~,i]=min(abs([DEM.time]-date));
        DEM_day = DEM(i);

        assert(isa(Products, 'struct'), 'Error (run_cBathyCT): Products must be a stucture as defined in user_input_products.')
        assert((isfield(Products, 'type') && isfield(Products, 'frameRate')), 'Error (run_cBathyCT): Products must be a stucture as defined in user_input_products.')

        switch camera_type
            case 'UAV'
                %% cutoff based on pixel resolution
                load(fullfile(odir, 'Processed_data', [oname '_IOEO']), 'R')
                load(fullfile(odir, 'Processed_data', 'Initial_coordinates'), 'C')
                [cutoff] = pixel_res(R, C);
        end

        ids_xtransect = find(ismember(string({Products.type}), 'xTransect'));
        for pp = ids_xtransect % repeat for all xTransects
            %% cBathyCT

            %% Bathy from Survey
            cBathyCT(pp).date = date;
            cBathyCT(pp).location = location;
            switch camera_type
                case 'UAV'
                    cBathyCT(pp).flight = flight;
                case 'ARGUS'
                    cBathyCT(pp).cam = cam;
            end
            cBathyCT(pp).y_loc = Products(pp).y;
            [x2,y2,f] = ll2utm(Products(pp).lat, Products(pp).lon,'nad83');
            y2 = y2 + Products(pp).y;
            [lat,lon]=utm2ll(x2,y2,f,'nad83');

            cBathyCT(pp).origin.ll = [lat, lon];
            cBathyCT(pp).origin.utm = [x2,y2];
            cBathyCT(pp).x10 = [Products(pp).xlim(2): Products(pp).dx:Products(pp).xlim(1)]';
            [~,i]=min(abs(mean(DEM_day.Y,2) - cBathyCT(pp).origin.utm(2)));
            cBathyCT(pp).survey.x = DEM_day.X(i,:);
            cBathyCT(pp).survey.y = DEM_day.Y(i,:);
            cBathyCT(pp).survey.z = DEM_day.Z(i,:);

            cBathyCT(pp).ct.x = fliplr(Products(pp).Eastings);
            cBathyCT(pp).ct.y = fliplr(Products(pp).Northings);

            cBathyCT(pp).survey.z_interp = interp1(cBathyCT(pp).survey.x, cBathyCT(pp).survey.z, cBathyCT(pp).ct.x);

            cBathyCT(pp).tide = Products(pp).tide;
            cBathyCT(pp).min_tide=DEM_day.min_tide;

            %% Load timestacks
            % if isempty(find(all([contains(tt, oname), contains(tt, ['y_' char(string(Products(pp).y)) '.00'])], 2)==1));

            viewId1=find(all([contains(timestack_png.Files, oname), contains(timestack_png.Files, ['y_' char(string(Products(pp).y)) 'm'])], 2)==1);


            viewId2=find(all([contains(prediction_png.Files, oname), contains(prediction_png.Files, ['y_' char(string(Products(pp).y)) 'm'])], 2)==1);
            if ~isempty(viewId1) & ~isempty(viewId2)
                if dd == 1
                    timestack = readimage(timestack_png, viewId1);
                else
                    timestack = fliplr(imrotate(readimage(timestack_png, viewId1), -90));
                end
                prediction = readimage(prediction_png, viewId2);


                %%
                % wave crests should be a binary image
                if size(prediction,3) ~= 1
                    prediction = rgb2gray(prediction);
                end

                cBathyCT(pp).timestack = timestack;
                cBathyCT(pp).waves = prediction;
                if size(cBathyCT(pp).timestack,3)~=1
                    timestack = im2gray(cBathyCT(pp).timestack);
                end
                aa=find(median(timestack,2)==0); if isempty(aa); aa=size(timestack,1);end
                % make sure that timestack is less than 25% black
                if ((length(find(timestack==0))/(size(timestack,1)*size(timestack,2))) < 0.25 && aa(1) < round(2*size(timestack,1)/3)) || aa(1) > round(9.5*size(timestack,1)/10)
                    pp
                    %% cBathy
                    load(fullfile(odir, 'Processed_data', [oname '_cBathy.mat']), 'bathy')

                    [idx,idy]=find(bathy.fCombined.h(:,3*round(size(bathy.fCombined.h,2)/4):end) < 5);
                    bathy.fCombined.h(idx, 3*round(size(bathy.fCombined.h,2)/4)-1+idy)=NaN;
                    bathy.fCombined.h = fliplr(bathy.fCombined.h)-cBathyCT(pp).tide;
                    bathy.fCombined.hErr = fliplr(bathy.fCombined.hErr);

                    [~,dist] = dsearchn(cBathyCT(pp).origin.utm,[bathy.coords.Eout(:) bathy.coords.Nout(:)]);
                    [~,i]=min(dist); i = rem(i,size(bathy.coords.Eout,1));
                    if i ~= 0
                        cBathyCT(pp).cbathy.x = bathy.coords.Eout(i,:);
                        cBathyCT(pp).cbathy.y = bathy.coords.Nout(i,:);
                        cBathyCT(pp).cbathy.z = -bathy.fCombined.h(i,:);
                        cBathyCT(pp).cbathy.zerr = bathy.fCombined.hErr(i,:);
                        cBathyCT(pp).cbathy.z_interp = interp1(cBathyCT(pp).cbathy.x, cBathyCT(pp).cbathy.z, cBathyCT(pp).ct.x);
                        cBathyCT(pp).cbathy.zerr_interp = interp1(cBathyCT(pp).cbathy.x, cBathyCT(pp).cbathy.zerr, cBathyCT(pp).ct.x);

                        %% Wave Celerity
                        Video = find_crests(cBathyCT(pp));
                        cBathyCT(pp).crests = Video.crests;
                        clear Video
                        %% Breakpoint Finder
                        cBathyCT(pp).bp = breakpt_calculator(cBathyCT(pp));
                        % Blue dot: Unbroken, dot at end of track
                        % Green dot: Breakpoint location along wave track
                        % Red dot: Entire wave track broken, dot at beginning of track

                        %% cBathyCT
                        switch camera_type
                            case 'UAV'
                                cutoff_dc = interp2(cutoff.res.x+R.worldPose.Translation(1), cutoff.res.y+R.worldPose.Translation(2), cutoff.res.dcRange, cBathyCT(pp).ct.x,cBathyCT(pp).ct.y);
                                cutoff_da = interp2(cutoff.res.x+R.worldPose.Translation(1), cutoff.res.y+R.worldPose.Translation(2), cutoff.res.daRange, cBathyCT(pp).ct.x,cBathyCT(pp).ct.y);
                                xx = mean(diff(bathy.xm));
                                aa = find(sum([[cutoff_da > 3*xx]; [cutoff_dc > 3*xx]]',2) ~=0);
                                if isempty(aa)
                                    cutoff.cbathy = NaN;
                                else
                                    cutoff.cbathy = aa(end);
                                end

                                xx = Products(pp).dx;
                                aa = find(sum([[cutoff_da > 3*xx]; [cutoff_dc > 3*xx]]',2) ~=0);
                                if isempty(aa)
                                    cutoff.ct = NaN;
                                else
                                    cutoff.ct = aa(end);
                                end
                            case 'ARGUS'
                                % can be computed in the future
                                cutoff.cbathy = NaN;
                                cutoff.ct = NaN;
                        end

                        Video = func_cbathyCT(cBathyCT(pp), cutoff);
                        cBathyCT(pp).ct = Video.ct;
                        cBathyCT(pp).cbathy = Video.cbathy;
                        cBathyCT(pp).composite = Video.composite;
                        cBathyCT(pp).lims = Video.lims;
                        cBathyCT(pp).check = Video.check;
                        cBathyCT(pp).Error = Video.Error;
                    end % if i ~= 0
                end % if image less than 25% black

            end %  if ~isempty(viewId1) & ~isempty(viewId2)
        end % for pp = ids_xtransect % repeat for all xTransects

        close all
        figure(1);clf
        scatter3(DEM_day.X, DEM_day.Y, DEM_day.Z, 1,'k')
        hold on
        for pp = 1:length(cBathyCT)
            if ~isempty(cBathyCT(pp).composite)
                scatter3(cBathyCT(pp).ct.x,cBathyCT(pp).ct.y, flipud(cBathyCT(pp).composite.cbathy_hErr), 'r')
                scatter3(cBathyCT(pp).ct.x,cBathyCT(pp).ct.y, flipud(cBathyCT(pp).composite.cbathyCT), 'g')
            end
        end
        xlabel('Eastings (m)')
        ylabel('Northings (m)')
        zlabel('Elevation (NAVD88m)')
        title(oname)
        %%
        saveas(gcf, fullfile(odir, 'Processed_data', [oname '_RS_bathy.png']), 'png')

        CT = cBathyCT; CT = rmfield(CT, {'timestack', 'waves'});
        save(fullfile(odir, 'Processed_data', [oname '_CT']),'CT')
        save(fullfile(odir, 'Processed_data', [oname '_cBathyCT']),'cBathyCT', '-v7.3')

        grid_plot{1} =  fullfile(odir, 'Processed_data', [oname '_RS_bathy.png']);
        if exist('user_email', 'var')
            try
                sendmail(user_email{2}, [oname '- cBathyCT DONE'], grid_plot)
            end
        end % if exist('user_email', 'var')
    end %  for ff = 1 : length(flights)
end % for  dd = 1 : length(day_files)
close all
cd(global_dir)