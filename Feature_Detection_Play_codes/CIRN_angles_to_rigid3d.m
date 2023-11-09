% x is cross-shore (+ is offshore)
% y is alongshore (+ is N)
% Define translation vector
translation = [0 0 5]; % in meters
%translation = extrinsics(1:3);

pitch_angle = rad2deg(extrinsics(5))%71 % angles up from NADIR
azimuth_angle = rad2deg(extrinsics(4))%267% angles CW from North
roll_angle = rad2deg(extrinsics(6))%-0.45 % angle CW from flat

% Define rotation angles in degrees
azimuth = 270 - azimuth_angle; 
pitch = -180 + pitch_angle
roll = -roll_angle

% Convert rotation angles from degrees to radians
yaw_rad = deg2rad(azimuth);
pitch_rad = deg2rad(pitch);
roll_rad = deg2rad(roll);

% Create a rotation matrix based on the specified Euler angles
rotation_matrix = eul2rotm([roll_rad, pitch_rad, yaw_rad], 'ZYZ');

% Create a rigid3d object using translation and rotation
rT = rigid3d(rotation_matrix, translation);
%%
% Display the rigid transform
disp('Rigid Transformation Matrix:');
disp(rT.Translation);
%rT.Translation(1)=0;rT.Translation(2)=0;rT.Translation(3) =rT.Translation(3)- 70;
figure(1);clf
plotCamera(AbsolutePose=rT, AxesVisible=1)
hold on
translation = rT.Translation;
grid on
xlabel('x')
ylabel('y')
view(-180,90)
set(gca, 'YDir', 'reverse')

axis equal
xlim(translation(1)+[-5 5])
ylim(translation(2)+[-5 5])
zlim(translation(3)+[-5 5])
quiver(0, 0,  3, 0, 'LineWidth', 2, 'Color', 'g')
text(2.5, 0.2, 0, 'X_W')
quiver(0,0, 0, 3,  'LineWidth', 2, 'Color', 'g')
text(0.2, 2.5,0, 'Y_W')
quiver3(0,0,0,0, 0,3, 'LineWidth', 2, 'Color', 'g')
text(0.2, 0.2,2.5, 'Z_W')
%%
ex(1:3) = rT.Translation;
aa = rad2deg(rotm2eul(rT.Rotation, 'ZYZ'));
ex(4) = 90+aa(3)
ex(5) = 180+aa(2)
ex(6) = 90-aa(1);
ex(4:6)=deg2rad(ex(4:6));