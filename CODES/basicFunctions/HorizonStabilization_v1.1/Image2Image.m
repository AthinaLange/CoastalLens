function [u2, v2] = Image2Image(u1, v1, inc1, roll1, azi1, inc2, roll2, azi2, K)
% Image2Image Project points from one image to another with new incidence
% and roll.
%   [u2,v2] = Image2Image(u1,v1,inc1,roll1,azi1,inc2,roll2,azi2,K) projects
%   points at image coordinates (u1,v1) for a camera oriented with
%   incidence, inc1, roll, roll1, and azimuth, azi1 (in radians) to
%   coordinates (u2,v2) for a camera with angles, inc2, roll2, and azi2.
%   inc1, roll1, azi1, inc2, roll2, and azi2 are scalars. K is the 3x3
%   upper-triangular camera intrinsic matrix. u1 and v1 can be scalars,
%   vectors, or arrays, and must be of the same size. Outputs u2 and v2 are
%   the same size as u1 and v1.
%   
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.

R_roll1 = [cos(roll1), -sin(roll1), 0; sin(roll1), cos(roll1), 0; 0, 0, 1];
R_pitch1 = [1, 0, 0; 0, -cos(inc1), -sin(inc1); 0 sin(inc1) -cos(inc1)];
R_azi1 = [cos(azi1), 0, -sin(azi1);  0 1 0; sin(azi1), 0, cos(azi1)];
R1 = R_azi1*R_roll1*R_pitch1;

R_roll2 = [cos(roll2), -sin(roll2), 0; sin(roll2), cos(roll2), 0; 0, 0, 1];
R_pitch2 = [1, 0, 0; 0, -cos(inc2), -sin(inc2); 0 sin(inc2) -cos(inc2)];
R_azi2 = [cos(azi2), 0, -sin(azi2);  0 1 0; sin(azi2), 0, cos(azi2)];
R2 = R_azi2*R_roll2*R_pitch2;

uv2 = [K, zeros(3,1); zeros(1,3), 1]*[R2, zeros(3,1); zeros(1,3), 1]*...
    (([K, zeros(3,1); zeros(1,3), 1]*[R1, zeros(3,1); zeros(1,3), 1])\...
    [u1(:)'; v1(:)'; ones(size(u1(:)')); ones(size(u1(:)'))]);
v2 = reshape(uv2(2,:)./uv2(3,:),size(u1));
u2 = reshape(uv2(1,:)./uv2(3,:),size(u1));

end

