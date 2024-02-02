function [theta, r] = Angles2Horizon(inc,roll,K)
% Angles2Horizon Calculate the location of the horizon based on the camera
% incidence and roll.
%   [theta, r] = Angles2Horizon(inc,roll,K) calculates the horizon line
%   parameters theta (in radians) and r (in pixels), from the camera
%   incidence angle, inc, and roll angle, roll.  inc and roll can be
%   scalars, vectors or arrays and must be of the same size.  K is the 3x3
%   upper-triangular camera intrinsic matrix.  Outputs theta and r are the
%   same size as inc and roll.
%   
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.




fx = K(1,1); 
fy = K(2,2); 
cx = K(1,3); 
cy = K(2,3);
theta = atan(-fx./(fy*tan(roll)));
r = (fx*sin(roll).*cos(theta)-fy*cos(roll).*sin(theta))/tan(inc)+cx*cos(theta)+cy*sin(theta);

