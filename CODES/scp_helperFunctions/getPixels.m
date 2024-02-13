function [IrIndv, Xout, Yout, Z, Eastings, Northings] = getPixels(Products, extrinsics, intrinsics, I)

[xyz, Xout, Yout, Z,Eastings, Northings] = getCoords(Products);


[P, ~, R, IC] = intrinsicsExtrinsics2P(intrinsics, extrinsics);

% Find the Undistorted UV Coordinates atributed to each xyz point.
UV = P*[xyz'; ones(1,size(xyz,1))];
UV = UV./repmat(UV(3,:),3,1);  % Make Homogenenous

% So the camera image we are going to pull pixel values from is distorted.
% Our P matrix transformation assumes no distortion. We have to correct for
% this. So we distort our undistorted UV coordinates to pull the correct
% pixel values from the distorted image. Flag highlights invalid points
% (=0) using intrinsic criteria.
[~,~,flag] = distortUV(UV(1,:),UV(2,:),intrinsics);

% Find Negative Zc Camera Coordinates. Adds invalid point to flag (=0).
xyzC = R*IC*[xyz'; ones(1,size(xyz,1))];
bind= xyzC (3,:)<=0;
flag(bind)=0;

% Make into a singular matrix for use in the non-linear solver
UVd = [UV(1,:)' UV(2,:)'];
%UVd = [Ud; Vd];


%UVd = reshape(UVd,[],2);
s=size(Xout);
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
            if Ud(kk,j) > 0 && Ud(kk,j) < size(I,2) && Vd(kk,j) > 0 && Vd(kk,j) < size(I,1)

            % Note how Matlab organizes images, V coordinate corresponds to
            % rows, U to columns. V is 1 at top of matrix, and grows as it
            % goes down. U is 1 at left side of matrix and grows from left
            % to right.
            ir(kk,j,:)=I(Vd(kk,j),Ud(kk,j),:);
            end
        end
    end
end

% Save Rectifications from Each Camera into A Matrix
IrIndv=uint8(ir);

end

