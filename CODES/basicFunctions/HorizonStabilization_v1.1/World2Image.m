function [u, v] = World2Image(x, y, H, inc, roll, azi, K)
% World2Image Project points in world coordinates to image pixel
% coordinates.
%   [u,v] = World2Image(x,y,H,incidence,roll,azi,K) performs the projection
%   (sometimes called perspective tranformation or orthography) from points
%   at world coordinates (x,y,-H) to image coordinates (u,v) for a camera
%   positioned at (0,0,0) and oriented with incidence, inc, and roll, roll
%   (in radians). inc, roll, azi, and H are scalars.  K is the 3x3
%   upper-triangular camera intrinsic matrix. x and y can be scalars,
%   vectors, or arrays, and must be of the same size. Outputs u and v are
%   the same size as x and y.
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

xs = [K, zeros(3,1); zeros(1,3), 1]*[R, zeros(3,1); zeros(1,3), 1]*...
    [x(:)'; y(:)';  -H*ones(size(x(:)')); ones(size(x(:)'))];

u = xs(1,:)./xs(3,:);
v = xs(2,:)./xs(3,:);

u = reshape(u,size(x));
v = reshape(v,size(x));

end

