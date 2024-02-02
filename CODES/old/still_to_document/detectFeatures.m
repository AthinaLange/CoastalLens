function [Points] = detectFeatures(I, Method)

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
end

end