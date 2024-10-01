%% Determine breakpoint 
% of wave track from pixel intensity and gradient
% 
%% Input 
%   Video (structure) - from bathy_inversion.m
%   rr - index of which value in Video structure to use
% 
%% Output 
%   bp - array of breakpoint indices for each wave track
% 
%% Copyright 
% Athina Lange 2022
%
%%
function bp = breakpt_calculator(Video)
%%
% Image index starts in top left corner(go 0 far offshore and 5001 on beach)
%% Determine thresholds from histogram of pixel intensity

    fullgray = rgb2gray(Video.timestack);
    figure(1);clf
    h=histogram(fullgray);
    h.NumBins = 32;
    hold on
    % find maximum value of histogram - usually agrees with low threshold
    % (mostly blue/darker)
    y=h.Values';y(1)=0;y(end)=0; % ignore any peaks at 0 or 255 - just white or black (artifical)
    x = h.BinEdges(1:end-1)'+h.BinWidth/2;
    low_peak_loc = find(max(y)==y);

    % use maximum value as first approximation for a Gaussian distribution
    % of dark values (unbroken)
    mu1 = h.BinEdges(low_peak_loc) + h.BinWidth/2;
    sigma1 = mu1 - h.BinEdges(find(y(1:low_peak_loc)>=y(low_peak_loc)*.68)) + h.BinWidth/2;sigma1 = sigma1(1);
    totalcounts = h.BinWidth * (sum(y));
    f = fit(x,y,'gauss1', 'StartPoint', [ totalcounts/2 mu1 sigma1]); % fit Gaussian
    y1 = f(x);
    % remove 1st Gaussian from histogram 
    aa = y - y1;
    aa(1:low_peak_loc+2*round(f.c1./h.BinWidth))=0;
    aa(aa < 0)=0;
    
    % find new maximum value and use that as first approximation for a
    % Gaussian distribution of light values (broken)
    high_peak_loc = find(max(aa)==aa);
    mu2 = h.BinEdges(high_peak_loc) + h.BinWidth/2;
    sigma2 = h.BinEdges(find(y(high_peak_loc:end)>=y(high_peak_loc)*.68)) + h.BinWidth/2;sigma2 = sigma2(end);
    totalcounts = h.BinWidth * (sum(aa));
    f2 = fit(x,aa,'gauss1', 'StartPoint', [ totalcounts/2 mu2 sigma2]);
    y2 = f2(x);

    % Pull mean and sigma from two Gaussians
    lowthres = f.b1;
    lowsigma = f.c1;
    highthres = f2.b1;
    highsigma = f2.c1;
    % determine where the two Gaussians intersect
    splitthres=fzero(@(x) f(x) - f2(x), mu2);
    if splitthres < 0 || splitthres > 255
        splitthres = mean([highthres lowthres]);
    end
    
    % p(1) = plot([lowthres lowthres], [0 max([y(:);y2(:)])*1.1], 'LineWidth', 7,'Color', 'g');
    % p(2) = plot([highthres highthres], [0 max([y(:);y2(:)])*1.1], 'LineWidth', 7,'Color', 'r');
    % p(3) = plot([splitthres splitthres], [0 max([y(:);y2(:)])*1.1], 'LineWidth', 7,'Color', 'b');
    % 
    % fig = plot(f,x,y);
    % set(fig, 'LineWidth', 4, 'Color', 'g')
    % fig = plot(f2,x,y2);
    % set(fig, 'LineWidth', 4, 'Color', 'r')
    % legend off
    % legend(p, 'Low threshold', 'High threshold', 'Split threshold')
    % 
    % set(gca, 'FontSize', 40)
    % xlabel('Pixel Intensity')
    % ylabel('Counts')


    %% Heuristically determine breakpoint
    if ~isnan(highthres)
    
        bp = NaN(size(Video.crests.t,2),1); % initialize variable
        
        for id = 1:size(Video.crests.t,2) % loop through every wave track
            % want them back in index format
            idx = round(Video.crests.x(:,id).*10); 
            idt = round(Video.crests.t(:,id).*10);
            idx(isnan(idx))=[];
            idt(isnan(idt))=[];
            
            %%% Determine wave track pixel intensity and gradients

            % Average over 5 pixels prior in time and wave track
            clear aa
            for ii = 1:length(idt)
                aa(ii,:,:)=Video.timestack(idx(ii), idt(ii)-5:idt(ii),:);
            end
            agray=rgb2gray(aa);
           
            % asmooth - average pixel intensity with different smoothing
            % (different features appear)
            % grad - gradient of average pixel intensity
            asmooth1=smoothdata(mean(agray,2), 'gaussian', 75);
            grad1 = smoothdata(gradient(asmooth1), 'gaussian', 25);
            max_grad = find(max(grad1) == grad1); if isempty(max_grad); max_grad = length(grad1)/2; end; if max_grad > length(grad1)/2; max_grad = length(grad1)/2; end; max_grad = floor(max_grad);
            
            asmooth2 = smoothdata(mean(agray,2),'gaussian', 25);
            %maxid = find(max(asmooth1)==asmooth1);
            
            % Mathematical morphology gradient
            I = agray;
            se = strel(ones(35,1));
            basic_gradient = imdilate(I, se) - imerode(I, se);
            basic_gradient = smoothdata(mean(basic_gradient,2), 'gaussian', 50);
            max_morph =find(max(basic_gradient) == basic_gradient); if isempty(max_morph); max_morph = length(grad1)/2; end; max_morph = floor(max_morph);
            
            % Find width between thresholds for a difference criteria
            width_low = splitthres - lowthres;
            width = highthres - lowthres;
            %width_high = highthres - splitthres;
            
            %% 1st pass (not dealing with foam issues)

            % BLUE - all values below low threshold
            if (all(asmooth1 < lowthres + lowsigma)) && all(idx < 4250)
                bp(id) = 5001; % bp is onshore
            
            % WHITE - all values above high threshold OR all values until
            % maximum of gradient above high(ish) threshold (accounts for
            % waves that start broken, end breaking and rebreak)
  
            elseif (all(asmooth1 > highthres)) || all(asmooth1(1:max_morph) > splitthres + highsigma) || all(asmooth1(1:max_grad) > splitthres+highsigma)
                bp(id) = NaN; % bp is offshore
            
            % SOME BREAKING COMPONENT
            else
                % find maximum of gradient - specifies where wave goes from
                % dark to light, ie. wave breaking
                maxgrad_loc_pos = floor(find(max(grad1)==grad1));
                maxgrad_loc=find(islocalmax(grad1)==1);
                maxgrad_loc(maxgrad_loc == maxgrad_loc_pos)=[];
                % check that there are only one main peak (nothing within
                % 10% of peak
                if any(grad1(maxgrad_loc) > grad1(maxgrad_loc_pos)*.9)
                    maxgrad_opt2 = maxgrad_loc(find(grad1(maxgrad_loc) > grad1(maxgrad_loc_pos)*.9)); 
                    maxgrad_opt2(maxgrad_opt2 > maxgrad_loc_pos)=[]; % remove any points shoreward of the initial max gradient
                    if ~isempty(maxgrad_opt2) 
                        maxgrad_loc_pos = maxgrad_opt2(1);
                    end
                    
                end

                % find minima around max gradient of mean pixel intensity
                % for bounds around gradient
                % left - should be minima (assuming unbroken dark wave face)
                left = floor(find(islocalmin(asmooth1(1:maxgrad_loc_pos))==1)); if isempty(left);left = 1;end
                left2 = floor(find(islocalmin(asmooth2(1:maxgrad_loc_pos))==1));
                % right - should be maxima (assuming broken light wave face)
                right = floor(find(islocalmax(asmooth1(maxgrad_loc_pos:end))==1)+maxgrad_loc_pos-1); if isempty(right);right = length(asmooth1);end
                right2 = floor(find(islocalmax(asmooth2(maxgrad_loc_pos:end))==1)+maxgrad_loc_pos-1); if isempty(right2);right2 = length(asmooth1);end
                
                % check that left and right ids below/above thresholds
                % respectively. If not, or empty, replace with alternative values
                if any(asmooth2 > highthres)
                    if length(left) > 1
                        while ~isempty(left) 
                            if asmooth2(left(end)) > lowthres 
                                left(end) = [];
                            else
                                break
                            end
                        end
                        if isempty(left)
                            left=1;
                        end
                        left = left(end);
                    end
                    if length(right) > 1
                        while ~isempty(right) 
                            if asmooth2(right(1)) < splitthres 
                                right(1) = [];
                            else
                                break
                            end
                        end
                        if isempty(right)
                            right = length(asmooth1);
                        end
                        right = right(1);
                    end
                else
                    left = left(end);
                    right = right(1);
                end
                
                % if foam present at the beginning of the wave track, fix
                % max gradient location
                if  asmooth1(left) < asmooth1(right) && ((asmooth1(right2(1)) < splitthres) && abs(right2(1)-right) > 10 && length(find(islocalmax(grad1)==1))> 1 && (asmooth2(right2(1))-asmooth2(left) < width))
                    grad_cutoff = grad1(maxgrad_loc_pos)*.80;
                    if ~isempty(find(grad1(maxgrad_loc)>grad_cutoff))
                        maxgrad_loc = maxgrad_loc(find(grad1(maxgrad_loc)>grad_cutoff));
                    end
                    local_max = find(islocalmax(asmooth2)==1); local_max(local_max < maxgrad_loc(1))=[];;
                    if ~isempty(local_max) && asmooth2(local_max(1)) > highthres
                        maxgrad_loc_pos = maxgrad_loc(1);
                    end
                end
            
                % CLEAN BREAKPOINT - values on left of breakpoint are below
                % low threshold, values on right of breakpoint are above
                % high threshold, difference between local min and max
                % around gradient are different enought (width)
                if asmooth1(1) < highthres && ((all(asmooth1(1:left)< lowthres + lowsigma)) && ((asmooth2(right)-asmooth2(left) > width) || max(basic_gradient) > highthres) || (asmooth1(left) < lowthres) && (asmooth2(right)-asmooth2(left) > width))
                    bp(id)=idx(maxgrad_loc_pos); % bp is location of maximum gradient
                
                % FOAM COMPLICATING
                % all white
                elseif (asmooth1(1) > splitthres) || (length(find(asmooth1 > splitthres)) > length(asmooth1)*(2/3))
                    bp(id) = NaN; % bp is offshore
                % all blue
                elseif length(find(asmooth1 < splitthres)) > length(asmooth1)*(2/3) && max(abs(grad1)) <1 && asmooth1(1) < splitthres && all(idx < 4250)
                    bp(id) = 5001; % bp is onshore

                % breakpt
                elseif (asmooth1(1) < highthres && (asmooth2(right)-asmooth2(left) > width_low)) || (any(asmooth1 > highthres) && max(grad1) > 2)
                    bp(id) = idx(maxgrad_loc_pos); % bp is location of maximum gradient
                
                % if some of average track has some white foam, assume broken and put bp offshore
                elseif any(asmooth2 > splitthres) 
                    bp(id) = NaN; % bp is offshore

                % if all else fails, put 0 and then can remove that wave track
                else 
                    bp(id)=0;
                end
                
            end % end of 1st pass clean blue or white
        end % end of loop through wave tracks
%% Plot        
        figure;clf
        image(Video.timestack)
        hold on
        plot(Video.crests.t.*10,Video.crests.x.*10, 'r', 'LineWidth', 3)

        for id = 1:size(Video.crests.t,2)
            idx = Video.crests.x(:,id).*10;
            idt=Video.crests.t(:,id).*10;
            idx(isnan(idx))=[];
            idt(isnan(idt))=[];
            if bp(id)~=0
                if bp(id) == 5001
                    plot(idt(end),idx(end), 'b.', 'MarkerSize', 30)
                elseif isnan(bp(id))
                    plot(idt(1),idx(1), 'r.', 'MarkerSize', 30)
                else
                    maxloc_id = find(bp(id) == idx);
                    plot(idt(maxloc_id), idx(maxloc_id), 'g.', 'MarkerSize', 30)
                end
            end
        end

    else % if no high threshold present - return all 0
        bp = 0;
    end % end of high threshold present
end % end of function