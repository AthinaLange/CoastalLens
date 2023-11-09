function [dx,dy,u0,v0] = ProjectionErrorsXY(x,y,H0,inc0,roll0,azi0,K,dH,dInc,dRoll,dAzi)
% ProjectionErrorsXY Calculate the error in x and y for points at
% sea-surface coordinates (x,y) using an incorrect camera pose.
%   [dx,dy,u0,v0] =
%   ProjectionErrorsXY(x,y,H0,inc0,roll0,azi0,K,dH,dInc,dRoll,dAzi)
%   calculates dx and dy, the projection errors in x and y, for points
%   defined by sea-surface coordinates (x,y).  H0, inc0, roll0, and azi0
%   indicate the assumed camera height and angles (in radians), which lead
%   to pixel coordinates (u0,v0) for points at (x,y).  The errors in the
%   camera parameters, dH, dInc, dRoll, and dAzi, lead to errors in x and y
%   of dx and dy.  K is the 3x3 upper-triangular camera intrinsic matrix. x
%   and y can be scalars, vectors, or arrays, and must be of the same size.
%   Outputs dx, dy, u0, and v0 are the same size as x and y.
%
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.


[u0,v0] = World2Image(x,y,H0,inc0,roll0,azi0,K);
[u1,v1] = World2Image(x,y,H0+dH,inc0+dInc,roll0+dRoll,azi0+dAzi,K);
[x1,y1] = Image2World(u1,v1,H0,inc0,roll0,azi0,K);

dx = x1 - x;
dy = y1 - y;