%% G2_pixelInstruments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function generates pixel instruments for a given set of images and
% corresponding extrinsics/intrinsics. It works very similar to
% G1_imageProducts however instead of rectifying a uniform grid for
% rectified images, we rectify a set of points for bathymetric inversion,
% surface current, or run-up calculations. Rectifications can be made in
% both world and a local rotated coordinate system. However, for ease and
% accuracy, if planned to use in bathymetric inversion, surface current,
% or run-up applications, it should occur in local coordinates.

%  This can function can be used for a collection with variable (UAS)
%  and fixed intriniscs in addition to single/multi camera capability.


%  Input:
%  Entered by user below in Sections 1-3. In Section 1 the user will input
%  output names.  Section 2 will require information for the collection,
%  i.e. the directory of the images and extrinsics/intrinsics calculated by
%  C_singleExtrinsicSolution or F_variableExtrinsicSolution. Section 3 will
%  require information concerning the pixel instruments such as type,
%  coordinate systems, and dimensions.

% The user input of the code is prescribed for UASDemoData. However, one can
% uncomment lines in Section 5 for the FixedMultiCamDemoData.


% Output:
% A .mat file appended with _pixInst with the pixel instruments as well as
% images with the instruments plotted as well as instrument stack images.
% Rectification metadata will be included in the matfile.


%  Required CIRN Functions:
%  imageRectification
%     -cameraSeamBlend
%  xyz2DistUV
%   distortUV
%   intrinsicsExtrinsics2P
%  localTransformExtrinsics
%   localTransformPoints



%  Required MATLAB Toolboxes:
%  none


% This function is to be run sixth or fifth in the progression for fixed
% and UAS collections.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Section 2: User Input:  Collection Information

%  Enter the filepath of the saved CIRN IOEO calibration results produced by
%  C_singleExtrinsicSolution for fixed or F_variableExtrinsicSolutions for
%  UAS.
a_temp = ioeopath;
clear ioeopath

ioeopath{1}=a_temp;

% %  Enter the directory where your oblique imagery is stored. For UAS, the
% %  names of the images must match those in imageNames output produced by
% %  F_variableExtrinsicSolutions. For fixed cameras, the directory should
% %  only have images in it, nothing else.
% 
a_temp = imageDirectory;
clear imageDirectory
imageDirectory{1}=a_temp;
% 
clear a_temp

%% Section 3: User Input: Manual Entry of Time and Elevation
%  If a fixed station a time vector can be provided in the datenum format.
%  The length of the vector must match the number of images rectified and
%  coorectly correspond to each image. If using UAS or not desired, leave
%  empty. If a UAS collect this varibale is defined in
%  F_variableExrtrinsicSolutions.
t={};


%  If a Fixed station, most likely images will span times where Z is no
%  longer constant. We have to account for this in our Z grid. To do this,
%  enter a z vector below that is the same length as t. For each frame, the
%  entire z grid will be assigned to this value.  It is assumed elevation
%  is constant during a short
%  collect. If you would like to enter a z grid that is variable in space
%  and time, the user would have to alter the code to assign a unique Z in
%  every loop iteration. See section 3 of D_gridGenExampleRect for more
%  information. If UAS or not desired, leave empty.
zFixedCam={};

%% Section 4: User Input: Instrument Information

% Enter the filepath of the saved rectification grid created in
% D_gridGenExampleRect. Grid world coordinates need to be same coordinates
% as those in the extrinsics in ieopath. Note, resolution of the grid is
% irrelvant for instruments you desire. THe grid is used for defining a
% local coordinate system, and pulling z elevation values. THus, if you
% have a spatially variable Z grid, you may want grid dx,dy resolutions to be
% similar to your instruments.
gridPath=[odir '/Processed_data/GRID_' gname];

% Enter if the user prefers local (localFlag==1) or world (localFlag==0)
% coordinates as input. Not if localFlag==1, localAngle, localOrigin, and localX,Y,Z
% in the ioeopath must all be non-empty.
%localFlag=1;

%% Section 5: Load Files

% Load Grid File And Check if local is desired
load(gridPath)
if localFlag==1
    X=localX;
    Y=localY;
    Z=localZ;
end

% Load Camera IOEO and Image lists

%  Determine Number of Cameras
camnum=length(ioeopath);
clear L
for k=1:camnum
    % Load List of Collection Images
    L{k}=sort(split(string(ls(imageDirectory{k}))));L{1,1}(1)=[]; % Athina change
    L{1,1}=L{1,1}(1:5:end);
    % Load Extrinsics
    load(ioeopath{k})
    
    % Check if fixed or variable. If fixed (length(extrinsics(:,1))==1), make
    % an extrinsic matrix the same length as L, just with initial extrinsics
    % repeated.
    if length(extrinsics(:,1))==1
        extrinsics=repmat(extrinsics,length(L{k}(:)),1);
    end
    if localFlag==1
        extrinsics=localTransformExtrinsics(localOrigin,localAngle,1,extrinsics);
    end
    L{1,1}(length(extrinsics)+1:end)=[];
    % Aggreate Camera Extrinsics Together
    Extrinsics{k}=extrinsics
    Intrinsics{k}=intrinsics
    
    clear extrinsics
    clear intrinsics
end

%% Section 6: Initialize Pixel Instruments

% Make XYZ Grids/Vectors from Specifications.
[pixInst]=pixInstPrepXYZ(pixInst);

% Assign Z Elevations Depending on provided parameters.
% If pixInst.z is left empty, assign it correct elevation
for p=1:length(pixInst)
    if isempty(pixInst(p).z)==1
        if isempty(zFixedCam)==1 % If a Time-varying z is not specified
            pixInst(p).Z=interp2(X,Y,Z,pixInst(p).X,pixInst(p).Y); % Interpret from given grid
        end
        
        if isempty(zFixedCam)==0 % If a time varying z is specified
            pixInst(p).Z=pixInst(p).X.*0+zFixedCam(1); % Assign First Value for First Image, spatially constant elevation
        end
    end
end

%% Section 7: Plot Pixel Instruments

for k=1:camnum
    % Load and Display initial Oblique Distorted Image
    I=imread(strcat(imageDirectory{k}, '/', L{k}(1)));
    figure
    hold on
    
    imshow(I)
    hold on
    title('Pixel Instruments')
    
    % For Each Instrument, Determin UVd points and plot on image
    for p = 1:length(pixInst)
        
        % Put in Format xyz for xyz2distUVd
        xyz=cat(2,pixInst(p).X(:),pixInst(p).Y(:),pixInst(p).Z(:));
        
        %Pull Correct Extrinsics out, Corresponding In time
        
        extrinsics=Extrinsics{k}(1,:);
        intrinsics=Intrinsics{k};
        
        
        % Determine UVd Points from intrinsics and initial extrinsics
        [UVd] = xyz2DistUV(intrinsics,extrinsics,xyz);
        
        % Make A size Suitable for Plotting
        UVd = reshape(UVd,[],2);
        plot(UVd(:,1),UVd(:,2),'*')
        xlim([0 intrinsics(1)])
        ylim([0  intrinsics(2)])
        
        % Make legend
        le{p}= [num2str(p) ' ' pixInst(p).type ];
    end
    legend(le)
    
    clear I
    clear extrinsics
    clear intrinsics
end

% Allows for the instruments to be plotted before processing
pause(1)
savefig(['Processed_data/Pixels_' char(string(frameRate))])
%%
%% Section 7:  Loop for Collecting Pixel Instrument Data.

for j=1:length(L{1}(:))
    
    % For Each Camera
    for k=1:camnum
        % Load Image
        I{k}=imread(strcat(imageDirectory{k}, '/', L{k}(j)));
    end
    
    %  Loop for Each Pixel Instrument
    for p=1:length(pixInst)
        
        % Check if a time varying Z was specified. If not, wil just use constant Z
        % specified or interpolated from grid in Section 4 and 6 respectively.
        if isempty(pixInst(p).z)==1
            if isempty(zFixedCam)==0 % If a time varying z is specified
                pixInst(p).Z=pixInst(p).X.*0+zFixedCam(j); % Assign First Value for First Image, spatially constant elevation
            end
        end
        
        %Pull Correct Extrinsics out, Corresponding In time
        for k=1:camnum
            extrinsics{k}=Extrinsics{k}(j,:);
        end
        intrinsics=Intrinsics;
        
        % Pull RGB Pixel Intensities
        [Irgb]= imageRectifier(I,intrinsics,extrinsics,pixInst(p).X,pixInst(p).Y,pixInst(p).Z,0);
               
        % Convert To Grayscale
        [Igray]=rgb2gray(Irgb);
        
        % If First frame, initialize pixInst structure entries
        if j==1
            pixInst(p).Igray=Igray;
            pixInst(p).Irgb=Irgb;
        end
        
        % If not First frame, tack on as last dimension (time).
        if j~=1
            s=size(Igray);
            nDim= length(find(s~=1)); % Finds number of actual dimension is =1 (transects) or 2 (grid)nDim
            
            % For Gray Scale it is straight forward
            pixInst(p).Igray=cat(nDim+1,pixInst(p).Igray,Igray); % Add on last dimension (third if Grid, second if transects)
            
            % For RGB it is trickier since MATLAB always likes rgb values in
            % third dimension.
            % If a GridGrid Add in the fourth dimension
            if nDim==2
                pixInst(p).Irgb=cat(nDim+2,pixInst(p).Irgb,Irgb); % Add on last dimension (Always Fourth)
            end
            % If a Transect Grid Add in the second dimension
            if nDim==1
                pixInst(p).Irgb=cat(2,pixInst(p).Irgb,Irgb);
            end
            
        end
    end
      
    % Display progress
    disp([ 'Frame ' num2str(j) ' out of ' num2str(length(L{k}(:))) ' completed. ' num2str(round(j/length(L{k}(:))*1000)/10) '%'])
    
end

%% Section 8: Plot Instrument Data
% For Each Instrument Plot the Data, note, if Grid data only the first
% frame will be plotted.

for p=1:length(pixInst)
    
    %Create Figure and Add Title Specifying Instrument Number and Type
    figure;
    title([num2str(p) ' ' pixInst(p).type ])
    hold on
    
    % If Grid use rectificationPlotter
    if strcmp(pixInst(p).type,'Grid')==1
        rectificationPlotter(pixInst(p).Irgb(:,:,:,3),pixInst(p).X,pixInst(p).Y,1); % Plot First Frame RGB
    end
    
    % If Transect use stackPlotter
      
    if strcmp(pixInst(p).type,'xTransect')==1
        
        stackPlotter(pixInst(p).Irgb,pixInst(p).X,t, 'x', 1)
        
        %If t non empty, add datetick to axis
        if isempty(t)==0
            datetick('y')
        end
    end
      
    if strcmp(pixInst(p).type,'yTransect')==1
        stackPlotter(pixInst(p).Irgb,pixInst(p).Y,t, 'y', 1)
        %If t non empty, add datetick to axis
        if isempty(t)==0
            datetick('x')
        end
    end
end

%% Section 9: Save Instruments and Meta Data

% Save metaData and Grid Data
rectMeta.solutionPath=ioeopath;
rectMeta.imageDirectory=imageDirectory;
rectMeta.imageNames=L;
rectMeta.t=t;
rectMeta.worldCoord=worldCoord;

% If A local Grid Add Information
if localFlag==1
    rectMeta.localFlag=1;
    rectMeta.localAngle=localAngle;
    rectMeta.localOrigin=localOrigin;
end

save(strcat(odir, '/Processed_data/',oname, '_',string(frameRate),'_pixInst'), 'pixInst','rectMeta','t', '-v7.3')