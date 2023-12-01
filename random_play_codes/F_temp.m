  
    
    to = datetime(string(C.CreateDate(mov_id(1))), 'InputFormat', 'yyyy:MM:dd HH:mm:ss', 'TimeZone', 'America/Los_Angeles');
    to.TimeZone = 'UTC'
    to = datenum(to);
    %  Enter the dt in seconds of the collect. If not known, leave as {}. Under
    %  t, images will just be numbered 1,2,3,4.
    frameRate = 10;
    dts= 1./frameRate; %Seconds
    %
    L=sort(split(string(ls(idir)))); L=L(2:end); % Athina: changes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Section 2: User Input:  Initial Frame information

firstFrame = char(L(1))


scpZcoord='NAVD88; m units';


% Put SCP in format for distUV2XYZ
for k=1:length(scp)
    scpZ(k)=scp(k).z;
    scpUVd(:,k)=[scp(k).UVdo'];
end

%% Section 5: Find List of Images and Assign TIme


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
