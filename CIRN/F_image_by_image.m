%% Section 7: Start Solving Extrinsics for Each image.

%% Housekeeping
firstFrame = char(L(1))
ioeopath = [odir '/Processed_data/' oname '_IOEOInitial.mat'];
scppath = [odir '/Processed_data/' oname '_scpUVdInitial.mat'];
scpZcoord='NAVD88; m units';
imageDirectory = idir;

%% Section 4: Load IOEO and SCP files
% Load IOEO
load(ioeopath)
% Load SCP
load(scppath);
% Assign SCP Elevations to each SCP Point.
for k=1:length(scp)
    i=find(scpz(:,1)==scp(k).num);
    scp(k).z=scpz(i,2);
end
% Put SCP in format for distUV2XYZ
for k=1:length(scp)
    scpZ(k)=scp(k).z;
    scpUVd(:,k)=[scp(k).UVdo'];
end
%% Section 5: Find List of Images and Assign TIme

% Get List of images in directory
%L=sort(split(string(ls(idir)))); L=L(2:end); % Athina: changes

% Find Indicie of First Image. Assumes it is in same folder as
% ImageDirectory
chk=~contains(L, firstFrame); % Athina: change
ffInd=find(chk==0);

% Get List of Indicies (first frame to last). (Assumes that images are in
% order, and only images are in folder).
ind=ffInd:length(chk);

% Assign time vector, if dts is left empty, vector will just be image
% number
if isempty(dts)==0
    t=(dts./24./3600).*([1:length(ind)]-1)+ to;
else if isempty(dts)==1
        t=(1:length(ind))-1;
    end
end
%% Section 6: Initialize Extrinsic Values and Figures for Loop
In=imread(strcat(imageDirectory, '/', L(ffInd,:)));
f1=figure;
imshow(In)
hold on
for k=1:length(scp)
    plot(scp(k).UVdo(1),scp(k).UVdo(2),'ro','linewidth',2,'markersize',10)
end

if isempty(dts)==1
    title(['Frame: ' num2str(t(1))])
else
    title(['Frame 1: ' datestr(t(1))])
end


[xyzo] = distUV2XYZ(intrinsics,extrinsics,scpUVd,'z',scpZ);

extrinsics_n=extrinsics;
scpUVdn=scpUVd;

% Initiate Extrinsics Matrix and First Frame Imagery
extrinsicsVariable=nan(length(ind),6);
scpUVdn_full(1,:,:) = scpUVdn;
extrinsicsVariable(1,:) = extrinsics_n; % First Value is first frame extrinsics.
extrinsicsUncert(1,:) = initialCamSolutionMeta.extrinsicsUncert;

%%

for k = 2:ind(end)%2:ind(end)
    %%
    extrinsics_n = extrinsicsVariable(k-1,:);
    scpUVdn = squeeze(scpUVdn_full(k-1,:,:));

    % Assign last Known Extrinsics and SCP UVd coords
    extrinsics_o=extrinsics_n;
    scpUVdo=scpUVdn;
  
    In=imread(strcat(imageDirectory, L(k,:)));
     % Plot new Image and new UV coordinates, found by threshold and reprojected
    cla
    imshow(In)
    hold on
    % Find the new UVd coordinate for each SCPs
    for j=1:length(scp)
        [ Udn, Vdn, i, udi,vdi] = thresholdCenter(In,scpUVdo(1,j),scpUVdo(2,j),scp(j).R,scp(j).T,scp(j).brightFlag);   
        %Assingning New Coordinate Location
        scpUVdn(:,j)=[Udn; Vdn];
    end
    % Solve For new Extrinsics using last frame extrinsics as initial guess and
    % scps as gcps
    extrinsicsInitialGuess=extrinsics_o;
    extrinsicsKnownsFlag=[0 0 0 0 0 0];
    [extrinsics_n extrinsicsError]= extrinsicsSolver(extrinsicsInitialGuess,extrinsicsKnownsFlag,intrinsics,scpUVdo',xyzo);
    %%    
    if find(isnan(scpUVdn) == 1)
        ids = find(isnan(scpUVdn(1,:)));
        if ids == 1
            sprintf('Reclick pt: %i', ids)
        elseif ids > 1
            for ll = 1:length(ids)
                sprintf('Reclick pt: %i\n', ids(ll))
            end
        end

        [UVclick] = getpt(strcat(imageDirectory, L(k,:)), ids)
        for ll = 1:length(ids)
            scpUVdn(:,ids(ll)) = UVclick(ll,2:3)'
        end

    end
    %%
    % Save Extrinsics in Matrix
    scpUVdn_full(k,:,:)=scpUVdn;
    extrinsicsVariable(k,:)=extrinsics_n;
    extrinsicsUncert(k,:)=extrinsicsError;
        
    cla
    imshow(In)
    hold on
    
    % Plot Newly Found UVdn by Threshold
    plot(scpUVdn(1,:),scpUVdn(2,:),'ro','linewidth',2,'markersize',10)
    
    % Plot Reprojected UVd using new Extrinsics and original xyzo coordinates
    [UVd] = xyz2DistUV(intrinsics,extrinsics_n,xyzo);
    uvchk = reshape(UVd,[],2);
    plot(uvchk(:,1),uvchk(:,2),'yo','linewidth',2,'markersize',10)
    
    % Plotting Clean-up
    if isempty(dts)==1
        title(['Frame: ' num2str(t(k))])
    else
        title(['Frame ' num2str(k) ': ' datestr(t(k))])
    end
    legend('SCP Threshold','SCP Reprojected')
    pause(.05)

end


%%

%% Section 8: Plot Change in Extrinsics from Initial Frame

f2=figure;

% XCoordinate
subplot(6,1,1)
plot(t,extrinsicsVariable(:,1)-extrinsicsVariable(1,1))
ylabel('/Delta x')
title('Change in Extrinsics over Collection')

% YCoordinate
subplot(6,1,2)
plot(t,extrinsicsVariable(:,2)-extrinsicsVariable(1,2))
ylabel('/Delta y')

% ZCoordinate
subplot(6,1,3)
plot(t,extrinsicsVariable(:,3)-extrinsicsVariable(1,3))
ylabel('/Delta z')

% Azimuth
subplot(6,1,4)
plot(t,rad2deg(extrinsicsVariable(:,4)-extrinsicsVariable(1,4)))
ylabel('/Delta Azimuth [^o]')

% Tilt
subplot(6,1,5)
plot(t,rad2deg(extrinsicsVariable(:,5)-extrinsicsVariable(1,5)))
ylabel('/Delta Tilt[^o]')

% Swing
subplot(6,1,6)
plot(t,rad2deg(extrinsicsVariable(:,6)-extrinsicsVariable(1,6)))
ylabel('/Delta Swing [^o]')

% Set grid and datetick if time is provided
for k=1:6
    subplot(6,1,k)
    grid on
    
    if isempty(dts)==0
        datetick
    end
end

%% Section 9: Saving Extrinsics and Metadata
%  Saving Extrinsics and corresponding image names
extrinsics=extrinsicsVariable;
imageNames=L(ind);

% Saving MetaData
variableCamSolutionMeta.scpPath=scppath;
variableCamSolutionMeta.scpo=scp;
variableCamSolutionMeta.scpZcoord=scpZcoord;
variableCamSolutionMeta.ioeopath=ioeopath;
variableCamSolutionMeta.imageDirectory=imageDirectory;
variableCamSolutionMeta.dts=dts;
variableCamSolutionMeta.to=to;

% Calculate Some Statsitics
variableCamSolutionMeta.solutionSTD= sqrt(var(extrinsics));

%  Save File
save([odir '/Processed_data/' oname '_' num2str(frameRate) '_IOEOVariable' ],'extrinsics','variableCamSolutionMeta','imageNames','t','intrinsics')

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
%%
function [UVclick] = getpt(imagePath, ids)
 I=imread(imagePath);
    [r c t]=size(I);
    
    imagesc(1:c,1:r,I)
    axis equal
    xlim([0 c])
    ylim([0 r])
    xlabel({ 'Ud';'Click Here in Cross-Hair Mode To End Collection '})
    ylabel('Vd')
    hold on
    
    % Clicking Mechanism
    x=1;
    y=1;
    button=1;
    UVclick=[];
    
    for ii = 1:length(ids)    
        % Allow User To Zoom
        title('Zoom axes as Needed. Press Enter to Initiate Click')
        pause
        
        % Allow User to Click
        title('Left Click to Save. Right Click to Delete')
        [x,y,button] = ginput(1);

        % User Input for Number
        num=input('Enter GCP Number:');
        UVclick=cat(1,UVclick, [num x y]);
        % Plot GCP in Image
        plot(x,y,'ro','markersize',10,'linewidth',3)
        
        % Display GCP Number In Image
        text(x+30,y,num2str(num),'color','r','fontweight','bold','fontsize',15)
       
        zoom out

    end
end