%% get_rigidt_from_CIRN
%
% Go from CIRN extrinsics to MATLAB rigidtform2d object
%
%
%
function tform = get_rigidt_from_CIRN(extrinsics)
    [R] = CIRNangles2R(extrinsics(4), extrinsics(5), extrinsics(6));
    angles = rad2deg(extrinsics(4:6));
    angles(1) = 360 - angles(1); % CCW around Z
    angles(2) = 90 - angles(2);
    angles = deg2rad(angles);
    R = eul2rotm(angles);
    T = extrinsics(1:3)';
    
    tform = rigidtform3d(R,T);
end