%% get_products
% get_products returns extracted image pixel for coordinates of Products and saves Timex, Brightest and Darkest image products
%% Description
%
%   Inputs:
%           global_dir (string) : global directory - where CODES and (typically) DATA  are located.
%           day_files (structure) : folders of the days to process - requires day_files.folder and day_files.name
%           flights (structure) : folders of the flights to process - requires flights.folder and flights.name
%           extract_Hz (double) : extraction frame rate (Hz) - obtained from Products
%           R (structure) : extrinsics/intrinsics information
%                       intrinsics (cameraIntrinsics) : camera intrinsics as calibrated in the cameraCalibrator tool
%                       extrinsics_2d (projtform2d) : [1 x m] 2d projective transformation of m images
%                       worldPose (rigidtform3d) : orientation and location of camera in world coordinates, based off ground control location (pose, not extrinsic)
%                       t (datetime array) : [1 x m] datetime of images at various extraction rates in UTC
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
%
%   Returns:
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
% For each extraction frame rate:
%       - use 2D projective transformation to warp image, and extract pixel value from full panorama image
%
%% Function Dependenies
% getCoords
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024;

%% Data

if ~exist('global_dir', 'var') || ~exist('day_files', 'var') || ~isstruct(day_files) || ~isfield(day_files, 'folder') || ~isfield(day_files, 'name')
    disp('Missing global_dir and day_files. Please load in processing_run_DD_Month_YYYY.mat that has the day folders that you would like to process. ')
    [temp_file, temp_file_path] = uigetfile(pwd, 'processing_run_.mat file');
    load(fullfile(temp_file_path, temp_file)); clear temp_file*
    assert(isfolder(global_dir),['Error (get_products): ' global_dir 'doesn''t exist.']);

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
    assert(isfile(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat')),['Error (get_products): ' fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat') ' doesn''t exist.']);
end
%%
close all
for  dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_config_file.mat'), 'extract_Hz', 'flights')
    assert(exist('extract_Hz', 'var'), 'Error (get_products): extract_Hz must exist and be stored in ''day_config_file.mat''.')
    assert(isa(extract_Hz, 'double'), 'Error (get_products): extract_Hz must be a double or array of doubles.')
    assert(exist('flights', 'var'), 'Error (get_products): flights must exist and be stored in ''day_config_file.mat''.')
    assert(isa(flights, 'struct'), 'Error (get_products): flights must be a structure.')
    assert((isfield(flights, 'folder') && isfield(flights, 'name')), 'Error (get_products): flights must have fields .folder and .name.')

    % repeat for each flight
    for ff = 1 : length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        disp(oname)
        cd(odir)

        load(fullfile(odir, 'Processed_data', [oname '_Products.mat']), 'Products')
        assert(isa(Products, 'struct'), 'Error (get_products): Products must be a stucture as defined in user_input_products.')
        assert((isfield(Products, 'type') && isfield(Products, 'frameRate')), 'Error (get_products): Products must be a stucture as defined in user_input_products.')

        assert(isfile(fullfile(odir, 'Processed_data', [oname '_IOEO.mat'])), ['Error (get_products): ' fullfile(odir, 'Processed_data', [oname '_IOEO.mat']) 'doesn''t exist. R variable must be stored there.'])

        for hh = 1 : length(extract_Hz)
            imageDirectory = sprintf('images_%iHz', extract_Hz(hh));
            images = imageDatastore(imageDirectory);

            load(fullfile(odir, 'Processed_data', [oname '_IOEO_' char(string(extract_Hz(hh))) 'Hz']),'R')
            assert(exist('R', 'var'), ['Error (get_products): R must exist and be stored in ''' fullfile(odir, 'Processed_data', [oname '_IOEO.mat']) '''.'])
            assert(isfield(R, 'intrinsics'), 'Error (get_products): R must contain a cameraIntrinsics object. Please add R.intrinsics and save before proceeding. ')
            assert(isa(R.intrinsics, 'cameraIntrinsics'), 'Error (get_products): intrinsics must be a cameraIntrinsics object.')
            assert(isfield(R, 'extrinsics_2d'), 'Error (get_products): R must contain the projtform2d array of extrinsics. Please run get_extrinsics to get R.extrinsics_2d before proceeding. ')
            assert(isa(R.extrinsics_2d, 'projtform2d'), 'Error (get_products): extrinsics must be projtform2d array.')
            assert(isfield(R, 'worldPose'), 'Error (get_products): R must contain a rigidtform3d worldPose object. Please add R.worldPose and save before proceeding. ')
            assert(isa(R.worldPose, 'rigidtform3d'), 'Error (get_products): extrinsics must be rigidtform3d object.')

            if ~isfield(R, 't')
                load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'C', 'mov_id', 'tz')
                assert(exist('C', 'var'), 'Error (get_products): C must exist and be stored in ''Initial_coordinates.mat''. run get_metadata.')
                assert(isa(C, 'table'), 'Error (get_products): C must be a table. run get_metadata.')
                assert(exist('mov_id', 'var'), 'Error (get_products): mov_id must exist and be stored in ''Initial_coordinates.mat''. run [mov_id] = find_file_format_id(C, file_format = {''MOV'', ''MP4''}).')
                assert(isa(mov_id, 'double'), 'Error (get_products): mov_id must be a double or array of doubles. run [mov_id] = find_file_format_id(C, file_format = {''MOV'', ''MP4''}).')
                assert(exist('tz', 'var'), 'Error (get_products): tz (timezone) must exist and be stored in ''Initial_coordinates.mat''. run [tz] = select_timezone.')
                assert(isa(tz, 'string') || isa(tz, 'char'), 'Error (get_products): tz (timezone) must be timezone string. run [tz] = select_timezone.')

                dts = 1/extract_Hz(hh);
                to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', tz);
                to.TimeZone = 'UTC';
                to = datenum(to);
                t = (dts./24./3600).*((1:length(images.Files))-1)+ to;
                R.t = datetime(t, 'ConvertFrom', 'datenum', 'TimeZone', 'UTC');
                clear dts to C mov_id tz t
            end %  if ~isfield(R, 't')
            [Products.t] =  deal(R.t);

            %% construct panorama box
            imageSize= size(readimage(images,1));
            for i = 1:numel(R.extrinsics_2d)
                [xlim(i,:), ylim(i,:)] = outputLimits(R.extrinsics_2d(i), [1 imageSize(2)], [1 imageSize(1)]);
            end %  for i = 1:numel(R.extrinsics_2d)

            % Find the minimum and maximum output limits.
            xMin = min([1; xlim(:)]);
            xMax = max([imageSize(2); xlim(:)]);

            yMin = min([1; ylim(:)]);
            yMax = max([imageSize(1); ylim(:)]);

            % Width and height of panorama.
            width  = round(xMax - xMin);
            height = round(yMax - yMin);

            % Create a 2-D spatial reference object defining the size of the panorama.
            xLimits = [xMin xMax];
            yLimits = [yMin yMax];
            panoramaView = imref2d([height width], xLimits, yLimits);

            clear imageSize xlim ylim xMin xMax yMin yMax width height xLimits yLimits
            %% =========================== Products ==================================
            for viewId = 1:length(images.Files)
                if rem(viewId, 30/(1/extract_Hz(hh))) == 0 % show viewId every 30 sec
                    fprintf('viewId = %i\n', viewId)
                end % if rem(viewId, 30/(1/extract_Hz(hh))) == 0
                I = imwarp(undistortImage(readimage(images, viewId), R.intrinsics), R.extrinsics_2d(viewId), 'OutputView', panoramaView);
                for pp = 1:length(Products)
                    if extract_Hz(hh)== Products(pp).frameRate || rem(extract_Hz(hh),Products(pp).frameRate) == 0 % if sampleRate = frameRate or can be subsampled from frameRate
                        if rem(viewId-1, extract_Hz(hh)/Products(pp).frameRate)==0 % if subsampled framerate
                            %% FD
                            if viewId == 1
                                [xyz, localX, localY, Z, Eastings, Northings] = getCoords(Products(pp));
                                Products(pp).localX = localX;
                                Products(pp).localY = localY;
                                Products(pp).Eastings = Eastings;
                                Products(pp).Northings = Northings;
                                Products(pp).localZ = Z;
                                % Find appropriate shift for panoramaView
                                mask = imwarp(true(size(I,1),size(I,2)), R.extrinsics_2d(viewId), 'OutputView', panoramaView);
                                BW = boundarymask(mask);
                                [row, col] = find(BW == 1, 1,'first');
                                Products(pp).iP = round(world2img(xyz, pose2extr(R.worldPose), R.intrinsics))+[col row];
                            end %  if viewId == 1

                            clear Irgb_temp
                            for ii = 1:length(Products(pp).iP)
                                if any(Products(pp).iP(ii,:) <= 0) || any(Products(pp).iP(ii,[2 1]) >= panoramaView.ImageSize)
                                    Irgb_temp(ii, :) = uint8([0 0 0]);
                                else
                                    Irgb_temp(ii, :) = I(Products(pp).iP(ii,2), Products(pp).iP(ii,1),:);
                                end % if any(Products(pp).iP(ii,:) <= 0) || any(Products(pp).iP(ii,[2 1]) >= panoramaView.ImageSize)
                            end %  for ii = 1:length(Products(pp).iP)

                            if contains(Products(pp).type, 'Grid')
                                Products(pp).Irgb_2d(viewId, :,:,:) = reshape(Irgb_temp, size(Products(pp).localX,1), size(Products(pp).localX,2), 3);
                            else
                                Products(pp).Irgb_2d(viewId, :,:) = Irgb_temp;
                            end % if contains(Products(pp).type, 'Grid')

                            %% SCP
                            if R.scp_flag == 1
                                I = readimage(images, viewId);
                                [IrIndv, ~,~,~,~,~] = getPixels(Products(pp), R.extrinsics_scp(viewId,:), R.intrinsics_CIRN, I);
                                if contains(Products(pp).type, 'Grid')
                                    Products(pp).Irgb_scp(viewId, :,:,:) = IrIndv;
                                else
                                    Products(pp).Irgb_scp(viewId, :,:) = permute(IrIndv,[2 1 3]);
                                end % if contains(Products(pp).type, 'Grid')
                            end % if R.scp_flag == 1
                        end %  if rem(viewId-1, extract_Hz(hh)/Products(pp).frameRate)==0
                    end % if extract_Hz(hh)== Products(pp).frameRate || rem(extract_Hz(hh),Products(pp).frameRate) == 0

                end % for pp = 1:length(Products)

                % make ARGUS products
                if viewId == 1
                    iDark=double(I).*0+255; % Can't initialize as zero, will always be dark
                    iTimex=double(I).*0;
                    iBright=uint8(I).*0;
                end
                % Timex
                iTimex=iTimex+double(I);

                % Darkest: Compare New to Old value, save only the mimumum intensity as iDark
                iDark=min(cat(4,iDark,I),[],4);

                % Brightest: Compare New to Old value, save only the maximum intensity as iBright
                iBright=max(cat(4,iBright,I),[],4);

                % If Last Frame...finish the Timex Caculation
                if viewId == length(images.Files)
                    iTimex=uint8(iTimex./length(images.Files));
                end

            end % for viewId = 1:length(images.Files)
            imwrite(iTimex, fullfile(odir, 'Processed_data', 'Timex.png'))
            imwrite(iBright, fullfile(odir, 'Processed_data', 'Brightest.png'))
            imwrite(iDark, fullfile(odir, 'Processed_data', 'Darkest.png'))
            if isfield(Products, 'iP')
                Products = rmfield(Products, 'iP');
            end % if isfield(Products, 'iP')

            for pp = 1:length(Products)
                Products(pp).Irgb_2d=Products(pp).Irgb_2d(1:extract_Hz(hh)/Products(pp).frameRate:end,:,:,:);
                % Products(pp).Irgb_scp=Products(pp).Irgb_scp(1:extract_Hz(hh)/Products(pp).frameRate:end,:,:,:);
                Products(pp).t=Products(pp).t(1:extract_Hz(hh)/Products(pp).frameRate:end);
            end %  for pp = 1:length(Products)

            save(fullfile(odir, 'Processed_data', [oname '_Products']),'Products', '-append')
        end % for hh = 1 : length(extract_Hz)
        if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Rectifying Products DONE'])
        end % if exist('user_email', 'var')
    end %  for ff = 1 : length(flights)
end % for  dd = 1 : length(day_files)
close all
cd(global_dir)
