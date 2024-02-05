function [I_mask] = apply_binary_mask(I, mask)
%   apply_binary_mask returns a masked image.
%% Syntax
%           [I_mask] = apply_binary_mask(I, mask)
%
%% Description
%   Args:
%           I (uint8 image) : Image to apply mask to
%           mask (logical matrix) : binary mask to apply to image (same dimensions as I)
%
%   Returns:
%           I_mask (uint8 image) : Image with applied mask
%
%% Example 1
%
% I = readimage('DATA/20211215_Torrey/01/DJI_0001.JPG');
% [mask] = select_ocean_mask(I);
% [I_mask] = apply_binary_mask(I, mask);
% figure
% image(I_mask)
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023;
%%
assert(isa(I, 'uint8'), 'Error (apply_binary_mask): I must be an image.')
assert(isa(mask, 'logical'), 'Error (apply_binary_mask): mask must be an binary mask.')
assert(size(mask) == size(I, [1 2]), 'Error (apply_binary_mask): mask must be the same size as I.')

%%
I_mask = zeros(size(I),'like', I);
for ii = 1:size(I,3)
    aa=I(:,:,ii);
    aa(~mask)=0;
    I_mask(:,:,ii)=aa;
end % for ii = 1:size(I,3)

end