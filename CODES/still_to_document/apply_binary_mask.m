function [I_mask] = apply_binary_mask(I, mask)

for ii = 1:size(I,3)
    aa=I(:,:,ii);
    aa(~mask)=0;
    I_mask(:,:,ii)=aa;
end

end