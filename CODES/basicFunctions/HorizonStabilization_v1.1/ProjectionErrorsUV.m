function [dx,dy,x0,y0] = ProjectionErrorsUV(u,v,H0,inc0,roll0,azi0,K,dH,dInc,dRoll,dAzi)
% ProjectionErrorsUV Calculate the error in x and y for pixels at (u,v)
% using an incorrect camera pose.
%   [dx,dy,x0,y0] =
%   ProjectionErrorsUV(u,v,H0,inc0,roll0,azi0,K,dH,dInc,dRoll,dAzi)
%   calculates dx and dy, the projection errors in x and y, for points
%   defined by pixel coordinates (u,v).  H0, inc0, roll0, and azi0 indicate
%   the assumed camera height and angles (in radians), which lead to
%   sea-surface coordinates (x0,y0) for pixels (u,v).  The errors in the
%   camera parameters, dH, dInc, dRoll, and dAzi, lead to errors in x and y
%   of dx and dy.  K is the 3x3 upper-triangular camera intrinsic matrix. u
%   and v can be scalars, vectors, or arrays, and must be of the same size.
%   Outputs dx, dy, x0, and y0 are the same size as u and v.
%
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.


[x0,y0] = Image2World(u,v,H0,inc0,roll0,azi0,K);
[x1,y1] = Image2World(u,v,H0+dH,inc0+dInc,roll0+dRoll,azi0+dAzi,K);
dx = x1 - x0;
dy = y1 - y0;
