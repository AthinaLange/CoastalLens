function v = HorizonPixels(theta,r,u)
% HorizonPixels Calculate the vertical pixel location of the horizon at a
% specified horizontal pixel location for a given (theta,r) pair
%   v = HorizonPixels(theta,r,u) calculates the row coordinates, v, of the
%   horizon for the horizon line parameters theta (in radians) and r (in
%   pixels), at the column coordinates, u. Inputs theta and r are scalars,
%   and u can be a scalar, vector, or array.  Output v is of the same type
%   and size as u.
%
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.

v = (r-u*cos(theta))/sin(theta);