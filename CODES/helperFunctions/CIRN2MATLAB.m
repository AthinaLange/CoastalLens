function [rT] = CIRN2MATLAB(extrinsics)
%
% Go from (x,y,z, azimuth, pitch, roll) to worldPose in MATLAB
%
% (NOT 100% checked)
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Nov 2023

%%
    translation = extrinsics(1:3);
    
    pitch_angle = rad2deg(extrinsics(5)); % angles up from NADIR
    azimuth_angle = rad2deg(extrinsics(4)); % angles CW from North
    roll_angle = rad2deg(extrinsics(6)); % angle CW from flat
    
    % Define rotation angles in degrees
    azimuth = azimuth_angle-90; 
    pitch = -180 + pitch_angle;
    roll = -roll_angle;
    
    % Convert rotation angles from degrees to radians
    yaw_rad = deg2rad(azimuth);
    pitch_rad = deg2rad(pitch);
    roll_rad = deg2rad(roll);
    
    % Create a rotation matrix based on the specified Euler angles
    rotation_matrix = eul2rotm([roll_rad, pitch_rad, yaw_rad], 'ZYZ');
    
    % Create a rigid3d object using translation and rotation
    rT = rigidtform3d(rotation_matrix, translation);


end