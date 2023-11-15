%% make ARGUS products
function [iDark, iBright, iTimex] = makeARGUSproducts(images, R, intrinsics)
for viewId = 1:length(R)

    Irgb = readimage(images, (viewId));
    I = undistortImage(Irgb, intrinsics);
    Ir = imwarp(I, R(viewId), OutputView=imref2d(size(I)));

    if viewId == 1
        iDark=double(Ir).*0+255; % Can't initialize as zero, will always be dark
        iTimex=double(Ir).*0;
        iBright=uint8(Ir).*0;
    end

     iTimex=iTimex+double(Ir);
    
    % Darkest: Compare New to Old value, save only the mimumum intensity as
    % iDark
    iDark=min(cat(4,iDark,Ir),[],4);
    
    % Brightest: Compare New to Old value, save only the maximum intensity as
    % iBright
    iBright=max(cat(4,iBright,Ir),[],4);
    
    % If Last Frame...finish the Timex Caculation
    if viewId == length(R)
        iTimex=uint8(iTimex./length(R));
    end
    
end

%%
figure
imshow(iBright)

figure
imshow(iDark)

figure
imshow(iTimex)

end