function [extrinsics] = MATLAB2CIRN(rT)

extrinsics(1:3) = rT.Translation;
aa = rad2deg(rotm2eul(rT.Rotation, 'ZYZ'));
extrinsics(4) = 270 - aa(3);
extrinsics(5) = 180+aa(2);
extrinsics(6) = -aa(1);
extrinsics(4:6)=deg2rad(extrinsics(4:6));

end