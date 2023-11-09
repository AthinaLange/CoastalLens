function [inc, roll] = Horizon2Angles(theta,r,K)
% Horizon2Angles Calculate camera incidence and roll based on the location
% of the horizon in the image.
%   [inc,roll] = Horizon2Angles(theta,r,K) calculates the camera incidence
%   angle, inc, and roll angle, roll, from the horizon line parameters
%   theta (in radians) and r (in pixels).  theta and r can be scalars,
%   vectors or arrays and must be of the same size.  K is the 3x3
%   upper-triangular camera intrinsic matrix.  Outputs inc and roll are the
%   same size as theta and r.
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
roll = atan(-fx./(fy*tan(theta)));
inc = atan((fx*sin(roll).*cos(theta)-fy*cos(roll).*sin(theta))./...
    (r-cx*cos(theta)-cy*sin(theta)));
inc(inc<=0) = pi+inc(inc<=0);

