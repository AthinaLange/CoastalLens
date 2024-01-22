%% get_products
%
% Extracts image pixel for coordinates of products
%
% If using Feature Detection (Monocular Visual Odometry)
%   - use 2D projective transformation to warp image, and extract pixel value from full panorama image
%
% If using SCPs (similar to QCIT F_variableExtrinsicsSolution)
%  - project coordinates into image according to [x y z azimuth tilt roll] and extract pixel
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Nov 2023

close all
for dd = 1 : length(day_files)
    clearvars -except dd *_dir user_email day_files P
    cd(fullfile(day_files(dd).folder, day_files(dd).name))

    load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'))

    ids_grid = find(contains(extractfield(Products, 'type'), 'Grid'));
    ids_xtransect = find(contains(extractfield(Products, 'type'), 'xTransect'));
    ids_ytransect = find(contains(extractfield(Products, 'type'), 'yTransect'));


    % repeat for each flight
    for ff = 1 : length(flights)

        load(fullfile(day_files(dd).folder, day_files(dd).name, 'day_input_data.mat'), 'Products')
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [day_files(dd).name '_' flights(ff).name];
        cd(odir)

        for hh = 1 : length(extract_Hz)
            imageDirectory = sprintf('images_%iHz', extract_Hz(hh));
            images = imageDatastore(imageDirectory);

            load(fullfile(odir, 'Processed_data', [oname '_IOEOInitial']),'worldPose', 'extrinsics', 'intrinsics','ind_scp_method')
            if ind_scp_method == 1 % Using Feature Detection/Matching
                extrinsicsInitial = extrinsics;
                load(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_' char(string(extract_Hz(hh))) 'Hz' ]), 'extrinsics_transformations')
              
                %% construct panorama box
                imageSize= size(readimage(images,1));
                for i = 1:numel(extrinsics_transformations)
               
                    [xlim(i,:), ylim(i,:)] = outputLimits(extrinsics_transformations(i), [1 imageSize(2)], [1 imageSize(1)]);
                end

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


                    %% =========================== Feature Detection ==================================
                    for viewId = 1:length(images.Files)
                        viewId
                        I = imwarp(undistortImage(readimage(images, viewId), intrinsics), extrinsics_transformations(viewId), 'OutputView', panoramaView);
                        for pp = 1:length(Products)
                            %if rem(extract_Hz(hh),Products(pp).frameRate) == 0 % check if at correct extraction rate
                            %    if extract_Hz(hh) ~= Products(pp).frameRate  && rem(viewId-1, extract_Hz(hh)/Products(pp).frameRate)==0% if subsampled framerate
                                    
                                        if viewId == 1
                                            [xyz, Xout, Yout, Z] = getCoords(Products(pp), extrinsicsInitial);
                                            Products(pp).localX = Xout;
                                            Products(pp).localY = Yout;
                                            Products(pp).localZ = Z;
                                            %find orientation of original image in panoramaView
                                            mask = imwarp(true(size(I,1),size(I,2)), extrinsics_transformations(viewId), 'OutputView', panoramaView);
                                            BW = boundarymask(mask);
                                            [row, col] = find(BW == 1, 1,'first');

                                            Products(pp).iP = round(world2img(xyz, pose2extr(worldPose), intrinsics))+[col row];
                                        end

                                            clear Irgb_temp
                                            for ii = 1:length(Products(pp).iP)
                                                %%  XXX change this to allow for bigger grid XXX
                                                if any(Products(pp).iP(ii,:) <= 0) || any(Products(pp).iP(ii,[2 1]) >= intrinsics.ImageSize)
                                                    Irgb_temp(ii, :) = uint8([0 0 0]);
                                                else
                                                    Irgb_temp(ii, :) = I(Products(pp).iP(ii,2), Products(pp).iP(ii,1),:);
                                                end
                                            end
                                            if contains(Products(pp).type, 'Grid')
                                                Products(pp).Irgb_2d(viewId, :,:,:) = reshape(Irgb_temp, size(Products(pp).localX,1), size(Products(pp).localX,2), 3);
                                            else
                                                Products(pp).Irgb_2d(viewId, :,:) = Irgb_temp;
                                            end
            
                            %    end % if extract_Hz(hh) ~= Products(pp).frameRate  && rem(viewId-1, extract_Hz(hh)/Products(pp).frameRate)==0% if subsampled framerate
                          %  end % if rem(extract_Hz(hh),Products(pp).frameRate) == 0

                        end % for pp = 1:length(Products)
                    end % for viewId = 1:length(images.Files)
                Products = rmfield(Products, 'iP');

            elseif ind_scp_method == 2 % SCPs
                %% =========================== SCPs ==================================
                load(fullfile(odir, 'Processed_data', [oname '_IOEOVariable_SCP_' char(string(extract_Hz(hh))) 'Hz' ]),'extrinsics','intrinsics')
                intrinsics_CIRN = intrinsics;
                for viewId = 1:length(images.Files)
                    viewId
                    I = readimage(images, viewId);
                    for pp = 1:length(Products)
                   %     if rem(extract_Hz(hh),Products(pp).frameRate) == 0
                     %       if extract_Hz(hh) ~= Products(pp).frameRate  && rem(viewId-1, extract_Hz(hh)/Products(pp).frameRate)==0% if subsampled framerate

                                [IrIndv, Xout, Yout, Z] = getPixels(Products(pp), extrinsics(viewId,:), intrinsics_CIRN, I);
                                Products(pp).localX = Xout;
                                Products(pp).localY = Yout;
                                Products(pp).localZ = Z;
                                if contains(Products(pp).type, 'Grid')
                                    Products(pp).Irgb_scp(viewId, :,:,:) = IrIndv;
                                else
                                    Products(pp).Irgb_scp(viewId, :,:) = permute(IrIndv,[2 1 3]);
                                end
                      %      end % if extract_Hz(hh) ~= Products(pp).frameRate  && rem(viewId-1, extract_Hz(hh)/Products(pp).frameRate)==0% if subsampled framerate
                      %  end % if rem(extract_Hz(hh),Products(pp).frameRate) == 0
                    end % for pp = 1:length(Products)
                end %  for viewId = 1:length(images.Files)


            end % if ind_scp_method == 1 % Using Feature Detection/Matching

            save(fullfile(odir, 'Processed_data', [oname '_Products_' char(string(extract_Hz(hh))) 'Hz' ]),'Products', '-v7.3')
        end % for hh = 1 : length(extract_Hz)
    end % for ff = 1 : length(flights)
end % for dd = 1 : length(day_files)
%%

%% FUNCTIONS
function [IrIndv, Xout, Yout, Z] = getPixels(Products, extrinsics, intrinsics_CIRN, I)

[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);
localExtrinsics = localTransformExtrinsics([x2 y2], 270-Products.angle, 1, extrinsics);


if contains(Products.type, 'Grid')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;

    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    [iX, iY]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));

    % DEM stuff
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    iZ=iX*0+iz;

    X=iX; Y=iY; Z=iZ;
    [ Xout, Yout]= localTransformPoints([x2 y2], 270-Products.angle,1,X,Y);
    Z=Xout*0+iz;
    xyz = cat(2,Xout(:), Yout(:), Z(:));

elseif contains(Products.type, 'xTransect')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;
    iy = y2 + Products.y;

    X = [ixlim(1):Products.dx:ixlim(2)]';
    Y = X.*0+iy;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = X.*0 + iz;
    [ Xout, Yout]= localTransformPoints([x2 y2], 270-Products.angle,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
elseif contains(Products.type, 'yTransect')
    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    ix = x2 + Products.x;

    Y = [iylim(1):Products.dy:iylim(2)]';
    X = Y.*0+ix;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = Y.*0 + iz;
    [ Xout, Yout]= localTransformPoints([x2 y2], 270+Products.angle,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
end

[P, ~, R, IC] = intrinsicsExtrinsics2P(intrinsics_CIRN, localExtrinsics);

% Find the Undistorted UV Coordinates atributed to each xyz point.
UV = P*[xyz'; ones(1,size(xyz,1))];
UV = UV./repmat(UV(3,:),3,1);  % Make Homogenenous

% So the camera image we are going to pull pixel values from is distorted.
% Our P matrix transformation assumes no distortion. We have to correct for
% this. So we distort our undistorted UV coordinates to pull the correct
% pixel values from the distorted image. Flag highlights invalid points
% (=0) using intrinsic criteria.
[~,~,flag] = distortUV(UV(1,:),UV(2,:),intrinsics_CIRN);

% Find Negative Zc Camera Coordinates. Adds invalid point to flag (=0).
xyzC = R*IC*[xyz'; ones(1,size(xyz,1))];
bind= xyzC (3,:)<=0;
flag(bind)=0;

% Make into a singular matrix for use in the non-linear solver
UVd = [UV(1,:)' UV(2,:)'];
%UVd = [Ud; Vd];


%UVd = reshape(UVd,[],2);
s=size(X);
Ud=(reshape(UVd(:,1),s(1),s(2)));
Vd=(reshape(UVd(:,2),s(1),s(2)));

% Round UVd coordinates so it cooresponds to matrix indicies in image I
Ud=round(Ud);
Vd=round(Vd);

% Utalize Flag to remove invalid points. See xyzDistUV and distortUV to see
% what is considered an invalid point.
Ud(flag==0)=nan;
Vd(flag==0)=nan;

% dimension for rgb values.
ir=nan(s(1),s(2),3);

% Pull rgb pixel intensities for each point in XYZ
for kk=1:s(1)
    for j=1:s(2)
        % Make sure not a bad coordinate
        if isnan(Ud(kk,j))==0 & isnan(Vd(kk,j))==0
            % Note how Matlab organizes images, V coordinate corresponds to
            % rows, U to columns. V is 1 at top of matrix, and grows as it
            % goes down. U is 1 at left side of matrix and grows from left
            % to right.
            ir(kk,j,:)=I(Vd(kk,j),Ud(kk,j),:);
        end
    end
end

% Save Rectifications from Each Camera into A Matrix
IrIndv=uint8(ir);

end


function [xyz, Xout, Yout, Z] = getCoords(Products, extrinsics)

[y2,x2, ~] = ll_to_utm(Products.lat, Products.lon);
localExtrinsics = localTransformExtrinsics([x2 y2], Products.angle-270, 1, extrinsics);


if contains(Products.type, 'Grid')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;

    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    [iX, iY]=meshgrid(ixlim(1):Products.dx:ixlim(2),iylim(1):Products.dy:iylim(2));

    % DEM stuff
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    iZ=iX*0+iz;

    X=iX; Y=iY; Z=iZ;
    [Xout, Yout]=localTransformEquiGrid([x2 y2], Products.angle-270,1,iX,iY);
    Z=Xout.*0+iz;

    xyz = [Xout(:) Yout(:) Z(:)];


elseif contains(Products.type, 'xTransect')
    if Products.xlim(1) < 0; Products.xlim(1) = -Products.xlim(1); end
    ixlim = x2 - Products.xlim;
    iy = y2 + Products.y;

    X = [ixlim(1):Products.dx:ixlim(2)]';
    Y = X.*0+iy;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = X.*0 + iz;
    %Xout=X-x2;
    %Yout=Y-y2;
    [ Xout, Yout]= localTransformPoints([x2 y2], Products.angle-270,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
elseif contains(Products.type, 'yTransect')
    if Products.ylim(1) > 0; Products.ylim(1) = -Products.ylim(1); end
    if Products.ylim(2) < 0; Products.ylim(2) = -Products.ylim(2); end
    iylim = y2 + Products.ylim;

    ix = x2 + Products.x;

    Y = [iylim(1):Products.dy:iylim(2)]';
    X = Y.*0+ix;
    if isempty(Products.z); iz=0; else; iz = Products.z; end
    Z = Y.*0 + iz;
    [ Xout, Yout]= localTransformPoints([x2 y2],Products.angle-270,1,X,Y);
    xyz = cat(2,Xout(:), Yout(:), Z(:));
end
xyz = xyz+[x2 y2 0];

end

