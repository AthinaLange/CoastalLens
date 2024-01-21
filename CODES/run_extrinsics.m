%% run_extrinsics
%
% Tracks the image stabilization through flight
%
% If using Feature Detection (Monocular Visual Odometry)
%   - extract features in first frame
%   - for all subsequent images:
% 	    - detect SIFT features
% 	    - find matching features between current frame and previous frame
% 	    - find projective 2D transformation of current frame
%
% If using SCPs (similar to QCIT F_variableExtrinsicsSolution)
%   - Within radius of previous location of SCPs, find mean location of pixels above/below specified threshold. This becomes the new location of the SCP. Find new extrinsics based on new SCP locations.
%       - If no points above/below threshold, then user prompt to click the location of the point.
%       - If same point is clicked 5 times in the last 10 frames, then reasses radius and thresholds.
%       - If person walks across points, user can pause code and click on points until object gone. (STILL TBD)
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Nov 2023

%%  Input Data check
if exist('day_files','var') && isstruct(day_files) && isfield(day_files, 'folder') && isfield(day_files, 'name')
    %
else  % Load in all days that need to be processed.
    data_dir = uigetdir('.', 'DATA Folder');
    disp('Please select the days to process:')
    day_files = dir(data_dir); day_files([day_files.isdir]==0)=[]; day_files(contains({day_files.name}, '.'))=[];
    [ind_datafiles,~] = listdlg('ListString',{day_files.name}, 'SelectionMode','multiple', 'InitialValue',1, 'PromptString', {'Which days would you like to process?'});
    day_files = day_files(ind_datafiles);
end


if exist('global_dir', 'var')
    %
else % select global directory
    disp('Please select the global directory.')
    global_dir = uigetdir('.', 'UAV Rectification');
    cd(global_dir)
end

%% Previous scripts data check
for dd = 1 : length(day_files)
    clearvars -except dd ff *_dir user_email day_files flights
    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'))

    for ff = 1 : length(flights)

        % Input_data: Products, extract_Hz, and flights
        if ~exist(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'file')
            disp('Please create an input_data.mat file with Products, extract_Hz, and flights.')
            % flights
            flights = dir(fullfile(day_files(dd).folder, day_files(dd).name)); flights([flights.isdir]==0)=[]; flights(contains({flights.name}, '.'))=[]; flights(contains({flights.name}, 'GCP'))=[];

            % Products
            answer = questdlg('Do you have a .mat Products file?', 'Product file', 'Yes', 'No', 'Yes');
            switch answer
                case 'Yes'
                    disp('Please select file of products you want to load in.')
                    disp('For CPG: CPG_data/products_Torrey.mat') %% XXX
                    [temp_file, temp_file_path] = uigetfile(global_dir, 'Product file');
                    load(fullfile(temp_file_path, temp_file)); clear temp_file*

                    if ~exist('Products', 'var')
                        disp('Please create Products file.')
                        disp('For CPG: construct DEM for appropriate day')
                       % construct_MOPS_DEM %% XXX
                        user_input_products
                    end
                case 'No'
                    user_input_products
            end
            clear answer

            % extract_Hz
            info_Hz = unique([Products.frameRate]);
            extract_Hz = max(info_Hz);
            for hh = 1:length(info_Hz)
                if rem(max(info_Hz), info_Hz(hh)) == 0
                    sprintf('%i Hz data can be pulled from %i Hz data', info_Hz(hh), max(info_Hz))
                else
                    sprintf('%i Hz data CANNOT be pulled from %i Hz data', info_Hz(hh), max(info_Hz))
                    extract_Hz = [extract_Hz info_Hz(hh)];
                end
            end
            clear hh info_Hz
            save(fullfile(day_files(dd).folder, day_files(dd).name, 'input_data.mat'), 'extract_Hz', 'Products', 'flights', '-append')
        end

        % Initial_coordinates: C, mov_id
        if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Inital_coordinates.mat'), 'file')
            disp('Please get a table of the metadata in C, and the id''s of the movie files (mov_id).')
            temp_name = string(inputdlg({'What is the file prefix?'}));
            drone_file_name = temp_name(1);
            [C, jpg_id, mov_id] = get_metadata(fullfile(flights(ff).folder, flights(ff).name), [day_files(dd).name '_' flights(ff).name], drone_file_name);
            save(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', 'Inital_coordinates'),  'jpg_id', 'mov_id', 'C', '-append')
            sprintf('Store this variable in %s', 'Initial_coordinates.mat')
        end

        % IOEOVariable: ind_scp_method
        if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [day_files(dd).name '_' flights(ff).name '_IOEOVariable.mat']), 'file')
            disp('Please define a SCP method in ind_scp_method variable.')
            [ind_scp_method,tf] = listdlg('ListString',[{'Feature Matching'}, {'Using SCPs.'}],...
                'SelectionMode','single', 'InitialValue',1, 'PromptString', {'Extrinsics Method'});
            save(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [day_files(dd).name '_' flights(ff).name '_IOEOVariable.mat']),'ind_scp_method')
            sprintf('Store this variable in %s', [day_files(dd).name '_' flights(ff).name '_IOEOVariable.mat'])
        end

        % IOEOInitial: worldPose, R, intrinsics, extrinsics, intrinsics_CIRN
        if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [day_files(dd).name '_' flights(ff).name '_IOEOInitial.mat']), 'file')
            disp('Depending on the SCP method, please include extrinsics and intrinsics information.')
            disp('If using Feature Matching: worldPose, R and intrinsics.')
            disp('If using SCPs: extrinsics and intrinsics_CIRN')
            % TODO
            sprintf('Store this variable in %s', [day_files(dd).name '_' flights(ff).name '_IOEOInitial.mat'])
        end


        % scpUVdInitial: scp (requires ind_scp_method and extract_Hz
        load(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [day_files(dd).name '_' flights(ff).name '_IOEOVariable.mat']), 'ind_scp_method')
        if ind_scp_method == 2 % SCP
            extract_Hz_dir=dir(fullfile(flights(ff).folder, flights(ff).name));
            extract_Hz_dir([extract_Hz_dir.isdir]==0)=[]; extract_Hz_dir(~contains({extract_Hz_dir.name}, 'images_'))=[];
            for hh = 1:length(extract_Hz_dir)
                if ~exist(fullfile(flights(ff).folder, flights(ff).name, 'Processed_data', [day_files(dd).name '_' flights(ff).name '_scpUVdInitial_' char(string(extract(extract_Hz_dir(hh).name,digitsPattern))) 'Hz.mat']), 'file')
                    sprintf('For extract_Hz = %.1f Hz', char(string(extract(extract_Hz_dir(hh).name,digitsPattern))))
                    disp('Please define SCPs.')
                    % TODO
                    sprintf('Store this variable in %s', [day_files(dd).name '_' flights(ff).name '_scpUVdInitial_' char(string(extract(extract_Hz_dir(hh).name,digitsPattern))) 'Hz.mat'])
                end
            end % hh
        end % if ind_scp_method
    end % ff
end % dd


%% run_extrinsics
for dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'Products', 'extract_Hz', 'flights')

    % repeat for each flight
    for ff = 1 : length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        cd(odir)

        load(fullfile(odir, 'Processed_data', [oname '_IOEOVariable']),'ind_scp_method')

        for hh = 1 : length(extract_Hz)
            imageDirectory = sprintf('images_%iHz', extract_Hz(hh));
            mkdir(sprintf('warped_images_%iHz', extract_Hz(hh)));
            images = imageDatastore(imageDirectory); 

            load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'C', 'mov_id', 'tz')
            dts = 1/extract_Hz(hh);
            to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', tz);
            to.TimeZone = 'UTC';
            to = datenum(to);
            t=(dts./24./3600).*([1:length(images.Files)]-1)+ to;


            %% GET EXTRINSICS
            if ind_scp_method == 1 % Using Feature Detection/Matching
                %% ========================FeatureDetection============================================
                %           - Using neighboring images for feature detection
                %  ===================================================================================

                [panorama, extrinsics_transformations] = get_extrinsics_fd(odir, oname, images);
                save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_' char(string(extract_Hz(hh))) 'Hz' ]),'extrinsics_transformations', 't')

            elseif ind_scp_method == 2 % CIRN QCIT F
                %% ========================SCPs=====================================================

                if exist('user_email', 'var')
                    sendmail(user_email{2}, [oname '- Please start extrinsics through time with SCPs.'])
                end
                answer = questdlg('Ready to start SCPs?', ...
                    'SCPs begin',...
                    'Yes', 'Yes');

                load(fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz)) 'Hz']), 'scp')
                load(fullfile(odir, 'Processed_data',  [oname '_IOEOInitial']), 'extrinsics', 'intrinsics_CIRN')

                [extrinsics] = get_extrinsics_scp(odir, oname, extract_Hz(hh), images, scp, extrinsics, intrinsics_CIRN, t);


            end % if ind_scp_method == 1
        end % for hh = 1 : length(extract_Hz)
        if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Extrinsics through time DONE'])
        end
    end % for ff = 1 : length(flights)
end % for dd = 1:length(day_files)
clearvars -except *_dir user_email day_files
cd(global_dir)
