%% run_extrinsics
%
% Repeat for each day + flight
%
%   
%   - If using Stability Control Points (like in the CIRN QCIT), you will
%   have to select the search radius area and bright (dark) threshold prior
%   to retriving the extrinsics. 
%
%
%
%
%
%
%
%  Send email that image extraction complete
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%%
[ind_scp_method,tf] = listdlg('ListString',[{''}, {''}, {''}, {'Using SCPs.'}],...
                                                     'SelectionMode','single', 'InitialValue',4, 'PromptString', {'Extrinsics Method'});
%% ========================SCPs============================================
        %  If using SCPs for tracking pose through time, extra step is required - define intensity threshold
        %  - Define search area radius - center of brightest (darkest) pixels in this region will be chosen as stability point from one frame to the next.
        %  - Define intensity threshold of brightest or darkest pixels in search area
        %  =====================================================================
if ind_scp_method == 4 % Using SCPs (similar to CIRN QCIT)
    close all

    % repeat for each day
    for dd = 1 : length(data_files)
        clearvars -except dd *_dir user_email data_files ind_scp_method
        cd(fullfile(data_files(dd).folder, data_files(dd).name))
        
        load(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'))
        
        % repeat for each flight
        for ff = 1 : length(flights)
            odir = fullfile(flights(ff).folder, flights(ff).name);
            oname = [data_files(dd).name '_' flights(ff).name];
            cd(odir) 

            load(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'image_gcp', 'intrinsics', 'gcp_method')
            if strcmpi(gcp_method, 'manual_targets')
                % repeat for each extracted frame rate
                for hh = 1 : length(extract_Hz)
            
                    I=imread(fullfile(odir, ['images_' char(string(extract_Hz(hh))) 'Hz'], 'Frame_0001.jpg'));
                    hFig = figure(1);clf
                    imshow(I)
                    hold on
                    scatter(image_gcp(:,1), image_gcp(:,2), 50, 'y', 'LineWidth', 3)
                    for ii = 1:length(image_gcp)
                        text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
                    end
                    answer_z = questdlg('Are elevation values in GCP coordinates file?', ...
                                                      'SCP Elevation',...
                                                      'Yes', 'No', 'Yes');
                    switch answer_z
                            case 'Yes'
                                disp('Load in target GCP coordinates file.')
                                disp('For CPG: Should be under the individual day. gps_northings.txt')
                                 [temp_file, temp_file_path] = uigetfile({'*.txt'}, 'GCP Targets');
                                 load(fullfile(temp_file_path, temp_file)); clear temp_file*
                                 for gg = 1:length(gps_northings)
                                    gcp_options(gg,:) = sprintf('%i - %.2fm', gg, gps_northings(gg,4));
                                 end
                      end
                    
                    for gg = 1:length(image_gcp)
                        %% ========================radius============================================
                            %                           - Determine search area around bright or dark target. 
                            %  =====================================================================
                        hFig   
                        scp(gg).UVdo = image_gcp(gg,:);
                        scp(gg).num = gg;
                    
                        xlim([image_gcp(gg,1)-intrinsics(1)/10 image_gcp(gg,1)+intrinsics(1)/10])
                        ylim([image_gcp(gg,2)-intrinsics(2)/10 image_gcp(gg,2)+intrinsics(2)/10])
                    
                        prev_radius = 50;
                        h=rectangle('position',[image_gcp(gg,1)-prev_radius,image_gcp(gg,2)-prev_radius,2*prev_radius,2*prev_radius],'EdgeColor','r','linewidth',1);
                        
                        while true
                            new_radius = double(string(inputdlg({'Area of Interest Size'}, 'Click Enter with previous radius to finish.',1, {num2str(prev_radius)})));
                            if new_radius ~= prev_radius
                                delete(h)
                                h=rectangle('position',[image_gcp(gg,1)-new_radius,image_gcp(gg,2)-new_radius,2*new_radius,2*new_radius],'EdgeColor','r','linewidth',1);
                                prev_radius = new_radius;
                            else
                                break;
                            end % if new_radius ~= prev_radius
                        end % while true
                        scp(gg).R = prev_radius;
                    
                        %% ========================threshold============================================
                            %                           - Determine threshold value for bright (dark) point - used for tracking through images
                            %  =====================================================================
                         
                        I_gcp = I(round(scp(gg).UVdo(2)-scp(gg).R):round(scp(gg).UVdo(2)+scp(gg).R), round(scp(gg).UVdo(1)-scp(gg).R):round(scp(gg).UVdo(1)+scp(gg).R), :);
                        hIN = figure(2);clf
                        hIN.Position(3)=3*hIN.Position(4);
                        subplot(121)
                        imshow(rgb2gray(I_gcp))
                        colormap jet
                        hold on
                        cb = colorbar; caxis([0 256]);
                        answer = questdlg('Bright or dark threshold', ...
                                         'Threshold direction',...
                                         'bright', 'dark', 'bright');
                        scp(gg).brightFlag = answer;    
                        subplot(122)
                        
                        prev_threshold = 100;
                        switch answer
                            case 'bright'
                                mask = rgb2gray(I_gcp) > prev_threshold;
                            case 'dark'
                                mask = rgb2gray(I_gcp) < prev_threshold;
                        end
                        [rows, cols] = size(mask);
                        [y, x] = ndgrid(1:rows, 1:cols);
                        centroid = mean([x(mask), y(mask)]);
                        imshow(mask)
                        colormap jet
                        hold on
                        plot(centroid(1), centroid(2), 'w+', 'MarkerSize', 10);
                    
                        while true
                            new_threshold = double(string(inputdlg({'Threshold'}, 'Click Enter with previous threshold to finish.',1, {num2str(prev_threshold)})));
                            if new_threshold ~= prev_threshold
                                cla
                                switch answer
                                    case 'bright'
                                        mask = rgb2gray(I_gcp) > new_threshold;
                                    case 'dark'
                                        mask = rgb2gray(I_gcp) < new_threshold;
                                end
                                if length(x(mask)) == 1
                                    centroid(1)=x(mask);
                                else
                                    centroid(1) = mean(x(mask));
                                end
                                if length(y(mask)) == 1
                                    centroid(2)=y(mask);
                                else
                                    centroid(2) = mean(y(mask));
                                end
                                imshow(mask)
                                colormap jet
                                hold on
                                plot(centroid(1), centroid(2), 'w+', 'MarkerSize', 10);
                                prev_threshold = new_threshold;
                            else
                                break;
                            end % if new_threshold ~= prev_threshold
                        end % while true
                        scp(gg).T = prev_threshold;
                        close(hIN)
                        %% ========================elevation============================================
                            %                           - Pull corresponding elevation value
                            %  =====================================================================
                        switch answer_z
                            case 'Yes'
                                [ind_gcp,tf] = listdlg('ListString', gcp_options, 'SelectionMode','single', 'InitialValue',[1], 'PromptString', {'What ground control points' 'did you use?'});
                                scp(gg).z = gps_northings(ind_gcp, 4);
                            case 'No'
                                scp(gg).z = double(string(inputdlg({'Elevation'})));
                        end
            
                    end % for gg = 1:length(image_gcp)
                    save(fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz(hh))) 'Hz']), 'scp')
                end
            else
                disp('Ground control targets are required to use stability control points.')
            end % if strcmpi(gcp_method, 'manual_targets')
        end % for ff = 1:length(flights)
    end % for dd = 1:length(data_files)
end % if ind_scp_method == 4
%% CIRN QCIT F

if ind_scp_method == 4 % Using SCPs (similar to CIRN QCIT)
    
    close all
    for dd = 1:length(data_files)
        clearvars -except dd *_dir user_email data_files ind_scp_method
        cd(fullfile(data_files(dd).folder, data_files(dd).name))
        
        load(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'))
        
        % repeat for each flight
        for ff = 1% : length(flights)
            odir = fullfile(flights(ff).folder, flights(ff).name);
            oname = [data_files(dd).name '_' flights(ff).name];
            cd(odir) 

            % repeat for each extracted frame rate
            for hh = 1 : length(extract_Hz)
                
                imageDirectory = fullfile(odir, ['images_' char(string(extract_Hz(hh))) 'Hz']);

                % load SCP & extrinsics
                load(fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz(hh))) 'Hz']), 'scp')
                load(fullfile(odir, 'Processed_data',  [oname '_IOEOInitial']), 'extrinsics', 'intrinsics')
                
              
                L = dir(imageDirectory); L([L.isdir] == 1) = []; if ~isempty(L); L = string(extractfield(L, 'name')');end;  if ~isempty(L); L(L=='.DS_Store')=[];end
  
                load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'C', 'mov_id')
                dts = 1/extract_Hz(hh);
                to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', tz);
                to.TimeZone = 'UTC';
                to = datenum(to);
                t=(dts./24./3600).*([1:length(L)]-1)+ to;
                
                In=imread(fullfile(imageDirectory,L(1)));
                f1=figure;
                imshow(In)
                hold on
                for k=1:length(scp)
                    plot(scp(k).UVdo(1),scp(k).UVdo(2),'ro','linewidth',2,'markersize',10)
                end
                

                % Initiate Extrinsics Matrix and First Frame Imagery
                extrinsicsVariable=nan(length(L),6);
                extrinsicsVariable(1,:)=extrinsics; % First Value is first frame extrinsics.
               % extrinsicsUncert(1,:)=initialCamSolutionMeta.extrinsicsUncert;

                [xyzo] = distUV2XYZ(intrinsics, extrinsics, reshape([scp.UVdo],2,[]), 'z', [scp.z]);
                
                % Initiate and rename initial image, Extrinsics, and SCPUVds for loop
                extrinsics_new = extrinsics;
                scpUVd_new = reshape([scp.UVdo],2,[]);

                %% ========================SCPthroughTime============================================
                    %                           - Determine search area around bright or dark target. 
                    %  =====================================================================
                imCount=1;
                click_counter = 0;
                for k=2:100%length(L)
                    
                    % Assign last Known Extrinsics and SCP UVd coords
                    extrinsics_old=extrinsics_new;
                    scpUVd_old=scpUVd_new;
                    clear extrinsics_new scpUVd_new

                    %  Load the New Image
                    In=imread(fullfile(imageDirectory,L(k)));
                    
                    % Find the new UVd coordinate for each SCPs
                    for j=1:length(scp)
                        [Udn, Vdn, i, udi,vdi] = thresholdCenter(In, scpUVd_old(1,j), scpUVd_old(2,j), scp(j).R, scp(j).T, scp(j).brightFlag);
                        if any(isnan([Udn Vdn])) % check if isempty or isnan
                            click_counter = click_counter + 1;
                            if click_counter == 1
                                if exist('user_email', 'var')
                                    sendmail(user_email{2}, [oname '- Problem with SCPs. Please click on correct point.'])
                                end
                            end
                            sprintf('Reclick pt: %i', j)
                            cla
                            imshow(In)
                            hold on
                            plot(scpUVd_old(1,j),scpUVd_old(2,j),'ro','linewidth',2,'markersize',10)
                            legend('Previous point')
                            [Udn, Vdn] = getpts;
                        end

                        %Assinging New Coordinate Location
                        scpUVd_new(:,j)=[Udn; Vdn];
                    end
                        
                    % Solve For new Extrinsics using last frame extrinsics as initial guess and scps as gcps
                    extrinsicsInitialGuess = extrinsics_old;
                    extrinsicsKnownsFlag = [0 0 0 0 0 0];
                    [extrinsics_new, extrinsicsError] = extrinsicsSolver(extrinsicsInitialGuess,extrinsicsKnownsFlag,intrinsics,scpUVd_old',xyzo);
                        
                    % Save Extrinsics in Matrix
                    imCount=imCount+1;
                    scpUVdn_full(imCount,:,:)=scpUVd_new;
                    extrinsicsVariable(imCount,:)=extrinsics_new;
                    %extrinsicsUncert(imCount,:)=extrinsicsError;
                        
                    % Plot new Image and new UV coordinates, found by threshold and reprojected
                    cla
                   % figure
                    imshow(In)
                    hold on

                    % Plot Newly Found UVdn by Threshold
                    plot(scpUVd_new(1,:),scpUVd_new(2,:),'ro','linewidth',2,'markersize',10)

                    % Plot Reprojected UVd using new Extrinsics and original xyzo coordinates
                    [UVd] = xyz2DistUV(intrinsics,extrinsics_new,xyzo);
                    uvchk = reshape(UVd,[],2);
                    plot(uvchk(:,1),uvchk(:,2),'yo','linewidth',2,'markersize',10)

                    tt = char(L(k));
                    title(['Frame: ' tt(7:10)])
                    
                    legend('SCP Threshold','SCP Reprojected')
                    pause(.05)
                    % 
                end % for k = 2:length(L)

                
                %  Saving Extrinsics and corresponding image names
                extrinsics=extrinsicsVariable;
                imageNames=L;
                
                % Saving MetaData
                variableCamSolutionMeta.scpPath=fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz(hh))) 'Hz']);
                variableCamSolutionMeta.scpo=scp;
                variableCamSolutionMeta.ioeopath=fullfile(odir, 'Processed_data',  [oname '_IOEOInitial']);
                variableCamSolutionMeta.imageDirectory=imageDirectory;
                
                % Calculate Some Statsitics
                variableCamSolutionMeta.solutionSTD= sqrt(var(extrinsics));
                
                %  Save File
                save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_' char(string(extract_Hz(hh))) 'Hz' ]),'extrinsics','t','variableCamSolutionMeta','imageNames','intrinsics')
                
                %  Display
                disp(' ')
                disp(['Extrinsics for ' num2str(length(L)) ' frames calculated.'])
                disp(' ')
                disp(['X Standard Dev: ' num2str(variableCamSolutionMeta.solutionSTD(1))])
                disp(['Y Standard Dev: ' num2str(variableCamSolutionMeta.solutionSTD(2))])
                disp(['Z Standard Dev: ' num2str(variableCamSolutionMeta.solutionSTD(3))])
                disp(['Azimuth Standard Dev: ' num2str(rad2deg(variableCamSolutionMeta.solutionSTD(4))) ' deg'])
                disp(['Tilt Standard Dev: ' num2str(rad2deg(variableCamSolutionMeta.solutionSTD(5))) ' deg'])
                disp(['Swing Standard Dev: ' num2str(rad2deg(variableCamSolutionMeta.solutionSTD(6))) ' deg'])

                f2=figure; 
                f2.Position(4) = 1.5*f2.Position(4);
                f2.Position(3) = 2*f2.Position(4);
                
                % XCoordinate
                subplot(6,1,1)
                plot(t,extrinsics(:,1)-extrinsics(1,1))
                ylabel('\Delta x [m]')
                title(['Change in Extrinsics over Collection - ' char(string(extract_Hz(hh))) 'Hz'])
                
                % YCoordinate
                subplot(6,1,2)
                plot(t,extrinsics(:,2)-extrinsics(1,2))
                ylabel('\Delta y [m]')
                
                % ZCoordinate
                subplot(6,1,3)
                plot(t,extrinsics(:,3)-extrinsics(1,3))
                ylabel('\Delta z [m]')
                
                % Azimuth
                subplot(6,1,4)
                plot(t,rad2deg(extrinsics(:,4)-extrinsics(1,4)))
                ylabel('\Delta Azimuth [^o]')
                
                % Tilt
                subplot(6,1,5)
                plot(t,rad2deg(extrinsics(:,5)-extrinsics(1,5)))
                ylabel('\Delta Tilt[^o]')
                
                % Swing
                subplot(6,1,6)
                plot(t,rad2deg(extrinsics(:,6)-extrinsics(1,6)))
                ylabel('\Delta Swing [^o]')
                
                for k=1:6
                    subplot(6,1,k)
                    grid on
                    datetick
                end
                print(f2, '-dpng', fullfile(odir, 'Processed_data', ['scp_time_' char(string(extract_Hz(hh))) 'Hz.png']))

            end % for hh = 1 : length(extract_Hz)
            if exist('user_email', 'var')
                sendmail(user_email{2}, [oname '- SCPs through time DONE'])
            end
        end % for ff = 1 : length(flights)
    end % for dd = 1:length(data_files)
end % if ind_scp_method == 4

%%
% SCPs
FD_stuff % - has codes for feature detection and horizon stabilization
%% horizon
%
% include check that projection and detected horizon within threshold of
% each other 
%
%
L = dir('images_10Hz'); L([L.isdir] == 1) = []; if ~isempty(L); L = string(extractfield(L, 'name')');end;  if ~isempty(L); L(L=='.DS_Store')=[];end
               
for ll = 1%:length(L)
    clearvars -except L ll sky water horizon_line cameraParams extrinsics intrinsics dd *_dir user_email data_files ind_scp_method
    I = imread(fullfile('images_10Hz', L(ll)));
    I = undistortImage(I, cameraParams);
    
    % Stuff to do on 1st image - get sky and water point
    if ll == 1
        % figure(1);clf
        % imshow(I)
        % title('Please click first on a sky point, then on a water point. - Click outside of image if no horizon.')
        % 
        % a = drawpoint();
        % if (floor(a.Position(1)) == 0 || floor(a.Position(1)) == size(I,2) || floor(a.Position(2)) == 0 || floor(a.Position(2)) == size(I,1)) 
        %     break;  % Exit the loop when Enter is pressed
        % else
        %     sky = round(a.Position);
        % end
        % drawpoint('Position', sky, 'Label', ['Sky Point']);
        % 
        % b=drawpoint();
        % water = round(b.Position);
        % drawpoint('Position', water, 'Label', ['Water Point']);

        Horizon.R=7/6*6378*1000; % World Radius in Meters
        Horizon.h=extrinsics(3);
        Horizon.d=sqrt(2*Horizon.R*Horizon.h+Horizon.h^2);
        Horizon.deg=0;
        Horizon.eutm=extrinsics(1)+cos(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
        Horizon.nutm=extrinsics(2)+sin(pi/2-extrinsics(4)+Horizon.deg)*Horizon.d;
        Horizon.zh=0; % should be tide %% XXX TBD
        [UVd,flag] = xyz2DistUV(intrinsics,extrinsics,[Horizon.eutm' Horizon.nutm' Horizon.zh']);
        sky = round([UVd(1) UVd(2)/2]);
        water = round([UVd(1) UVd(2)+UVd(2)/2]);
        figure(1);clf
        imshow(I)
        hold on
        drawpoint('Position', sky, 'Label', ['Sky Point']);
        drawpoint('Position', water, 'Label', ['Water Point']);
       
    end
    
    [horizon_line(ll,:)] = get_horizon(I, sky, water);


     x = [0 size(I,2)];
     y = horizon_line(ll,1)*x + horizon_line(ll,2);
    
    if rem(ll,100)==0
        ll
        figure(ll);clf
        imshow(I)
        hold on
        plot(x,y,'g-')
        scatter(sky(1), sky(2), 50,'r','filled')
        scatter(water(1), water(2) , 50,'b','filled')
        toc
    end

    perc_20 = min(y)/5;
    sky =  round([mean(x) min(y) - perc_20]);
    water = round([mean(x) max(y) + perc_20]);
end


%% Objects


% Drone Data
