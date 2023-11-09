function [x, y] = Image2World(u, v, H, inc, roll, azi, K)
% Image2World Project points in image pixel coordinates to world
% coordinates.
%   [x,y] = Image2World(x,y,H,inc,roll,azi,K) performs the projection
%   (sometimes called perspective tranformation or orthography) from points
%   at image coordinates (u,v) to world coordinates (x,y,-H) for a camera
%   positioned at (0,0,0) and oriented with incidence, inc, roll, roll, and
%   azimuth, azi, (in radians). inc, roll, azi, and H are scalars.  K is
%   the 3x3 upper-triangular camera intrinsic matrix. u and v can be
%   scalars, vectors, or arrays, and must be of the same size. Outputs x
%   and y are the same size as u and v.
%   
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.

R_roll = [cos(roll), -sin(roll), 0; sin(roll), cos(roll), 0; 0, 0, 1];
R_pitch = [1, 0, 0; 0, -cos(inc), -sin(inc); 0 sin(inc) -cos(inc)];
R_azi = [cos(azi), 0, -sin(azi);  0 1 0; sin(azi), 0, cos(azi)];
R = R_azi*R_roll*R_pitch;

pw = ([K, zeros(3,1); zeros(1,3), 1]*[R, zeros(3,1); zeros(1,3), 1])\...
    [u(:)';  v(:)'; ones(size(u(:)')); ones(size(u(:)'))];

x = -pw(1,:)./pw(3,:)*H;
y = -pw(2,:)./pw(3,:)*H;

x = reshape(x,size(u));
y = reshape(y,size(u));


end

