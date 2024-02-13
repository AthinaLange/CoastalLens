function [extrinsics] = get_extrinsics_scp(odir,oname, extract_Hz, images, scp, extrinsics, intrinsics, t, cameraParams)
%  get_extrinsics_scp returns camera extrinsics using stability control points (following CIRN F)
%
%% Syntax
% 
%  [extrinsics] = get_extrinsics_scp(odir, oname, extract_Hz, images, scp, extrinsics, intrinsics, t)
%
%% Description 
% 
%   Args:
%           odir (string) : location of day/flight folder to load and save data
%           oname (string) : prefix name for current day/flight to load and save data
%           extract_Hz (double) : extraction frame rate (in Hz) to load and save data
%           images (imageDatastore) : Stores file name of m images to process
%           scp (structure) : scp location, radius and threshold (from define_SCP.m)
%           extrinsics (array) : [1 x 6] extrinsics as defined by CIRN
%           intrinsics (array) : [1 x 11] intrinsics as defined by CIRN
%           t (array) : [m x 1] datenum array of time for m images (for plotting)
%
%   Returns:
%          extrinsics (array) : [m x 6] extrinsics corresponding to m images
%               
%
%  computes change in [x y z azimuth tilt and roll] for every image based
%  on least-squares optimization of scp location shifts between frames. 
%
%% Citation Info 
% github.com/AthinaLange/CoastalLens
% Nov 2023; 


                In=undistortImage(readimage(images, 1), cameraParams);
                f1=figure('Name', 'Image Viewer', 'Position', [100, 100, 1200, 800]);
                handles.pauseButton = uicontrol('Style', 'pushbutton', 'String', 'Pause', 'Position', [20, 20, 60, 30]);
                handles.imageAxis = axes('Parent', f1, 'Position', [0.1, 0.1, 0.8, 0.8]);

                imshow(In, 'Parent', handles.imageAxis)
                hold on
                for k=1:length(scp)
                    plot(scp(k).UVdo(1),scp(k).UVdo(2),'ro','linewidth',2,'markersize',10)
                end

                % Initiate Extrinsics Matrix and First Frame Imagery
                extrinsicsVariable=nan(length(images.Files),6);
                extrinsicsVariable(1,:)=extrinsics; % First Value is first frame extrinsics.
                % extrinsicsUncert(1,:)=initialCamSolutionMeta.extrinsicsUncert;

                [xyzo] = distUV2XYZ(intrinsics, extrinsics, reshape([scp.UVdo],2,[]), 'z', [scp.z]);

                % Initiate and rename initial image, Extrinsics, and SCPUVds for loop
                extrinsicsVariable(1,:) = extrinsics;
                scpUVdn_full(1,:,:) = reshape([scp.UVdo],2,[]);
                imCount=1;
                click_counter = 0;
                clicks = zeros(length(scp), length(images.Files));
                %% ========================SCPthroughTime============================================
                %                           - Determine search area around bright or dark target.
                %  =====================================================================

                for k=2:length(images.Files)


                    % Assign last Known Extrinsics and SCP UVd coords
                    extrinsics_old=squeeze(extrinsicsVariable(k-1,:));
                    scpUVd_old=squeeze(scpUVdn_full(k-1,:,:));
                    clear extrinsics_new scpUVd_new

                    %  Load the New Image
                    In=undistortImage(readimage(images, k), cameraParams);
                    [m,n,~]=size(In);


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

                            % Check if you've clicked last 5 pts:
                            clicks(j, k) = 1;
                            if k > 10 && sum(clicks(j, k-9:k))>=5
                                disp('Change SCP')
                                scp(j) = redefine_SCP(scp(j), In, scpUVd_old(:,j));
                            end

                            sprintf('Reclick pt: %i', j)
                            fig = figure(100);clf
                            imshow(In)
                            hold on
                            plot(scpUVd_old(1,j),scpUVd_old(2,j),'ro','linewidth',2,'markersize',10)
                            legend('Previous point')
                            xlim([scpUVd_old(1,j)-n/10 scpUVd_old(1,j)+n/10])
                            ylim([scpUVd_old(2,j)-m/10 scpUVd_old(2,j)+m/10])

                            a = drawpoint();
                            zoom out
                            Udn= a.Position(1);
                            Vdn= a.Position(2);
                        end

                        %Assinging New Coordinate Location
                        scpUVd_new(:,j)=[Udn; Vdn];
                    end % for j=1:length(scp)

                    % Solve For new Extrinsics using last frame extrinsics as initial guess and scps as gcps
                    extrinsicsInitialGuess = extrinsics_old;
                    extrinsicsKnownsFlag = [0 0 0 0 0 0];
                    [extrinsics_new, extrinsicsError] = extrinsicsSolver(extrinsicsInitialGuess,extrinsicsKnownsFlag,intrinsics,scpUVd_old',xyzo);

                    % Save Extrinsics in Matrix
                    scpUVdn_full(k,:,:)=scpUVd_new;
                    extrinsicsVariable(k,:)=extrinsics_new;
                    %extrinsicsUncert(imCount,:)=extrinsicsError;

                    % Plot new Image and new UV coordinates, found by threshold and reprojected
                    figure(f1);cla
                    % figure
                    imshow(In)
                    hold on

                    % Plot Newly Found UVdn by Threshold
                    plot(scpUVd_new(1,:),scpUVd_new(2,:),'ro','linewidth',2,'markersize',10)

                    % Plot Reprojected UVd using new Extrinsics and original xyzo coordinates
                    [UVd] = xyz2DistUV(intrinsics,extrinsics_new,xyzo);
                    uvchk = reshape(UVd,[],2);
                    plot(uvchk(:,1),uvchk(:,2),'yo','linewidth',2,'markersize',10)

                    tt = char(images.Files(k));
                    title(['Frame: ' tt(end-7:end-4)])

                    legend('SCP Threshold','SCP Reprojected')
                    pause(.15)
                    set(handles.pauseButton, 'Callback', @(src, event) pauseLoop(src, event));
                    % Check if the pause button is pressed
                    while ishandle(handles.pauseButton) && strcmp(get(handles.pauseButton, 'UserData'), 'pause')
                        pause(0.1);
                    end
                    %saveas(gcf, sprintf('people_on_dot/Frame_%i.jpg', k))
                    %
                end % for k = 2:length(L)

%%
                %  Saving Extrinsics and corresponding image names
                extrinsics=extrinsicsVariable;
                imageNames=images;

                % Saving MetaData
                variableCamSolutionMeta.scpPath=fullfile(odir, 'Processed_data',  [oname '_scpUVdInitial_' char(string(extract_Hz)) 'Hz']);
                variableCamSolutionMeta.scpo=scp;
                variableCamSolutionMeta.ioeopath=fullfile(odir, 'Processed_data',  [oname '_IOEOInitial']);
                
                % Calculate Some Statsitics
                variableCamSolutionMeta.solutionSTD= sqrt(var(extrinsics));

                %  Save File
                save(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_' char(string(extract_Hz)) 'Hz' ]),'extrinsics','t','variableCamSolutionMeta','imageNames','intrinsics', 'scpUVdn_full')

                %  Display
                disp(' ')
                disp(['Extrinsics for ' num2str(length(images.Files)) ' frames calculated.'])
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
                title(['Change in Extrinsics over Collection - ' char(string(extract_Hz)) 'Hz'])

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
                print(f2, '-dpng', fullfile(odir, 'Processed_data', ['scp_time_' char(string(extract_Hz)) 'Hz.png']))

end


