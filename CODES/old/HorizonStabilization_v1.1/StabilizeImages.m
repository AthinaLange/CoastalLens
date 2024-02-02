function [stabFrames] = StabilizeImages(frames, inc1, roll1, azi1, inc2, roll2, azi2, K)
% StabilizeImages Stabilize single images or video frames.  Requires Matlab
% Image Processing Toolbox.
%   [stabFrames] =
%   StabilizeImages(frames,inc1,roll1,azi1,inc2,roll2,azi2,K) warps images
%   contained in frames (an MxNxP array) from a camera oriented with
%   incidence, inc1, roll, roll1, and azimuth, azi1 (in radians) to a
%   camera with constant angles inc2, roll2, and azi2.  inc1, roll1, and
%   azi1 may be scalars or vectors of length P. inc2, roll2, and azi2 are
%   scalars. K is the 3x3 upper-triangular camera intrinsic matrix. Output
%   stabFrames is an MxNxP array of the same type as frames.
%
%   Written by Michael Schwendeman, June 2014
%
%   Citation: Schwendeman, M., J. Thomson, 2014: "A Horizon-tracking Method
%   for Shipboard Video Stabilization and Rectification."  In Review, J.
%   Atmos. Ocean. Tech.


imrefobj = imref2d(size(frames(:,:,1)));
stabFrames = frames;
numFrames = size(frames,3);
if length(inc1)==1
    inc1 = repmat(inc1,[numFrames, 1]);
end
if length(roll1)==1
    roll1 = repmat(roll1,[numFrames, 1]);
end
for i=1:numFrames
    R_roll1 = [cos(roll1(i)), -sin(roll1(i)), 0; sin(roll1(i)), cos(roll1(i)), 0; 0, 0, 1];
    R_pitch1 = [1, 0, 0; 0, -cos(inc1(i)), -sin(inc1(i)); 0 sin(inc1(i)) -cos(inc1(i))];
    R_azi1 = [cos(azi1), 0, -sin(azi1);  0 1 0; sin(azi1), 0, cos(azi1)];
    R1 = R_azi1*R_roll1*R_pitch1;
    R_roll2 = [cos(roll2), -sin(roll2), 0; sin(roll2), cos(roll2), 0; 0, 0, 1];
    R_pitch2 = [1, 0, 0; 0, -cos(inc2), -sin(inc2); 0 sin(inc2) -cos(inc2)];
    R_azi2 = [cos(azi2), 0, -sin(azi2);  0 1 0; sin(azi2), 0, cos(azi2)];
    R2 = R_azi2*R_roll2*R_pitch2;
    R = (K*R2/(K*R1))';
    tform = projective2d(R);
    stabFrames(:,:,i) = imwarp(frames(:,:,i),tform,'OutputView',imrefobj);
end