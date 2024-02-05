function [Points] = detectFeatures(I, Method)
% detectFeatures returns method-specified feature points in image.
%% Syntax
%  [Points] = detectFeatures(I, Method)
%
%% Description
%
%   Args:
%           I (uint8 image) : grayscale image to extract features from
%           Method (string) : Feature type (default : 'SIFT')
%
%   Returns:
%          Points (SIFTPoints) : stored SIFT interest points (or whichever method chosen)
%
%
%% Example 1
% I = readimage('DATA/20211215_Torrey/01/DJI_0001.JPG');
% I = im2gray(I);
% [Points] = detectFeatures(I, 'SIFT');
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024;

%% Data
assert(isa(I, 'uint8'), 'Error (detectFeatures): I must be an image.')
assert(isa(Method, 'string'), 'Error (detectFeatures): Method must be a string.')
assert(contains(Method, {'SIFT' ,'SURF', 'BRISK', 'ORB', 'KAZE'}), 'Error (detectFeatures): Method must be one of the following allowed features: SIFT, BRISK, ORB, KAZE or SURF.')

if length(size(I))==3 % if still rgb
    I = im2gray(I);
end % if length(size(I))==3 
%% detectFeatures
if contains(Method, 'SIFT')
    Points   = detectSIFTFeatures(I);
elseif contains(Method, 'BRISK')
    Points   = detectBRISKFeatures(I);
elseif contains(Method, 'ORB')
    Points   = detectORBFeatures(I);
elseif contains(Method, 'KAZE')
    Points   = detectKAZEFeatures(I);
elseif contains(Method, 'SURF')
    Points   = detectSURFFeatures(I);
end % if contains(Method, 'SIFT')

end