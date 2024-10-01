function Video = find_crests(Video)
%%% Find the average line of the wave crests as determined by the neural network
% binarize and skeletonize the wave crests
prediction_clean = bwskel(imbinarize(imcomplement(Video.waves)),'MinBranchLength',20);

% turn the wave crests into 0 (wave crest) or 255 (not)
prediction_gray = ones(size(Video.waves))*255;
prediction_gray(prediction_clean==1)=0;

%%% Find midpoint of each x segment - only want 1 value for every x point
for tt = 1:size(Video.waves,2)
    for xx = 1:size(Video.waves,1)-20
        if prediction_gray(xx,tt)==0 % if marked as wave crest
            aa = find(prediction_gray(xx:xx+20,tt)==0);
            if length(aa)==1
                midpt = 0;
                aa=[];
            elseif length(aa)==2
                aa(1)=[];
            elseif mod(length(aa),2)==1 % odd
                midpt = aa((length(aa)-1)/2);
                aa(midpt+1==aa)=[];
            elseif mod(length(aa),2)==0 % even
                midpt = aa((length(aa))/2)-1;
                aa(midpt==aa)=[];
            end
            prediction_gray(xx+aa-1,tt)=255; % find which points should be unmarked
        end
    end
end

%%% Find peaks - 1st point of wave crest
clear peaks_t peaks_x
box = 20; % can choose to change search box size HERE - higher frequency days may require smaller size

% go through full image and stop when you find a 0 pixel (wave crest)
% if all the pixels previously in time and space within the search
% box are 255, then it is the beginning of a crest, and save the
% coordinates.
for tt = box+1:size(Video.waves,2)
    for xx = box+1:size(Video.waves,1)
        if prediction_gray(xx,tt)==0
            if (sum(prediction_gray(xx-box:xx, tt-box:tt), 'all')+255)/((box+1)^2) == 255
                % any other 0 value will skew results to not be = 255
                peaks_t(tt) = tt;
                peaks_x(tt) = xx;
                tt = tt+1;
            end
        end
    end
end
% remove any weirdness
peaks_x(peaks_t==0)=[];
peaks_t(peaks_t==0)=[];
%%% Find wave trains from peaks - change box size for next wave point HERE
clear crests_t crests_x

for nn = 1:length(peaks_t) % loop through all peaks found

    ll=1;
    crests_t(ll,nn) = peaks_t(nn);
    crests_x(ll,nn) = peaks_x(nn);

    D=1;
    while min(D) < 20 % loop through wave train
        tt = crests_t(ll,nn);
        xx = crests_x(ll,nn);
        ll=ll+1;
        % if the wave train is at the right most edge of the image,
        % stop looking - avoids throwing an eppor here
        if xx > size(prediction_gray,1)-30 | tt > size(prediction_gray,2)-5
            break
        end
        % within a box size onshore and in future time, find all
        % wave crest pixels.
        [idx,idt]=find(prediction_gray(xx+1:xx+30, tt+1:tt+5)==0);
        if length(idx) < 2
            D=51;
            break
        end
        X = [1,1];
        Y = [idt,idx];%Y(1,:)=[];
        % find the point that has the shortest euclidean distance
        % from the previously found point
        [D,~] = pdist2(X,Y,'euclidean','Smallest',1);
        if length(find(min(D)==D))>1
            id = find(min(D)==D); id=id(1);
            crests_t(ll,nn) = tt+idt(id);
            crests_x(ll,nn) = xx+idx(id);
        else
            crests_t(ll,nn) = tt+idt(find(min(D)==D));
            crests_x(ll,nn) = xx+idx(find(min(D)==D));
        end
    end
end
% remove any weirdness
crests_t(crests_t==0)=NaN;
crests_x(crests_x==0)=NaN;

%%% Clean up short segements - change length of segment HERE
for nn = length(peaks_t):-1:1
    if find(~isnan(crests_t(:,nn))) < 75
        crests_t(:,nn)=[];
        crests_x(:,nn)=[];
    end
end

% need to go from pixel units to real world units (0.1m, 0.1s)
crests_x = crests_x./10;
crests_t = crests_t./10;

%%% Get velocity
clear c c_short c_new c_real c_long
% compute velocity using forward Euler
for nn = 1:size(crests_t,2)
    c(:,nn)=diff(crests_x(:,nn))./diff(crests_t(:,nn));
end
c(end+1,:)=NaN(1, size(crests_t,2));

% Interpolate to full grid
for nn = 1:size(crests_t,2)
    x10 = Video.x10;
    aa = interp1(crests_x(~isnan(c(:,nn)),nn), c(~isnan(c(:,nn)),nn), x10, 'nearest');
    c_real(:,nn) = fliplr(aa);
    t_slots(:,nn) = interp1(crests_x(~isnan(crests_t(:,nn)),nn), crests_t(~isnan(crests_t(:,nn)),nn), x10, 'nearest');
end

% images are named from top left corner, but we define x10 going from
% bottom to top (shore -> offshore)
x10 = (flipud(x10))';

%%% find cutoffs where not enough data present - change % for cutoff HERE

% find total number of counts (histogram of 'observations')
for nn = 1:length(x10)
    counts(nn) = sum(~isnan(c_real(nn,:)));
end
max_id = round(median(find(max(counts)==counts)));
cutoff = max(counts).*.10;
ab=abs(counts-max(counts).*.10); % difference in values
min_diff = min(ab(max_id:end));
% find offshore cutoff where less than 10% of the max counts are present in the data
for ii = max_id:1:length(x10)
    if ab(ii) == min_diff
        offshore_cutoff = ii;
        break
    end
end
min_diff = min(ab(1:max_id));
% find onshore cutoff where less than 10% of the max counts are present in the data
for ii = max_id:-1:1
    if ab(ii) == min_diff
        onshore_cutoff = ii;
        break
    end
end
% remove 'uncertain' data
c_real(1:onshore_cutoff,:)= NaN;
c_real(offshore_cutoff:end,:)=NaN;

%%% redo c analysis with 25m wave spacing
c_new = NaN(size(crests_t,1)-1, size(crests_t,2));
for nn = 1:size(crests_t,2)
    for ll = 1:length(crests_x(:,nn))-1
        if isnan(crests_x(ll,nn)) == 1
            break
        else
            clear id
            id = find(crests_x(:,nn) >= crests_x(ll,nn)-12.5 & crests_x(:,nn) <= crests_x(ll,nn)+12.5);
            if ll == 1
                c_new(ll,nn) = diff(crests_x(ll:ll+1,nn))./diff(crests_t(ll:ll+1,nn));
            elseif isnan(crests_x(ll+1,nn)) == 1
                break
            elseif length(id) > 1
                points = [crests_x(id,nn) crests_t(id,nn)];
                sampleSize = 2; % number of points to sample per trial
                maxDistance = 0.1; % max allowable distance for inliers

                fitLineFcn = @(points) polyfit(points(:,1),points(:,2),1); % fit function using polyfit
                evalLineFcn = @(model, points) sum((points(:, 2) - polyval(model, points(:,1))).^2,2);

                [modelRANSAC, inlierIdx] = ransac(points,fitLineFcn,evalLineFcn, sampleSize,maxDistance);

                c_new(ll,nn)= 1/modelRANSAC(1);
            else
                c_new(ll,nn)=diff(crests_x(ll:ll+1,nn))./diff(crests_t(ll:ll+1,nn));
            end
        end
    end
end
for nn = 1:size(crests_t,2)
    x10 = Video.x10;
    aa = interp1(crests_x(~isnan(c_new(:,nn)),nn), c_new(~isnan(c_new(:,nn)),nn), x10, 'nearest');
    c_long(:,nn) = fliplr(aa);
end
x10 = (flipud(x10))';
for nn = 1:length(x10); counts(nn) = sum(~isnan(c_long(nn,:))); end
max_id = round(median(find(max(counts)==counts)));
cutoff = max(counts).*.10; ab=abs(counts-max(counts).*.10);
min_diff = min(ab(max_id:end)); for ii = max_id:1:length(x10); if ab(ii) == min_diff; offshore_cutoff = ii; break; end; end
min_diff = min(ab(1:max_id)); for ii = max_id:-1:1; if ab(ii) == min_diff; onshore_cutoff = ii; break; end; end
c_long(1:onshore_cutoff,:)= NaN;
c_long(offshore_cutoff:end,:)=NaN;

%%% redo c analysis with 15m wave spacing
c_new = NaN(size(crests_t,1)-1, size(crests_t,2));
for nn = 1:size(crests_t,2)
    for ll = 1:length(crests_x(:,nn))-1
        if isnan(crests_x(ll,nn)) == 1
            break
        else
            clear id
            id = find(crests_x(:,nn) >= crests_x(ll,nn)-7.5 & crests_x(:,nn) <= crests_x(ll,nn)+7.5);
            if ll == 1
                c_new(ll,nn) = diff(crests_x(ll:ll+1,nn))./diff(crests_t(ll:ll+1,nn));
            elseif isnan(crests_x(ll+1,nn)) == 1
                break
            elseif length(id) > 1
                points = [crests_x(id,nn) crests_t(id,nn)];
                sampleSize = 2; % number of points to sample per trial
                maxDistance = 0.1; % max allowable distance for inliers

                fitLineFcn = @(points) polyfit(points(:,1),points(:,2),1); % fit function using polyfit
                evalLineFcn = @(model, points) sum((points(:, 2) - polyval(model, points(:,1))).^2,2);

                [modelRANSAC, inlierIdx] = ransac(points,fitLineFcn,evalLineFcn, sampleSize,maxDistance);

                c_new(ll,nn)= 1/modelRANSAC(1);

            else
                c_new(ll,nn)=diff(crests_x(ll:ll+1,nn))./diff(crests_t(ll:ll+1,nn));
            end
        end
    end
end
for nn = 1:size(crests_t,2)
    x10 = Video.x10;
    aa = interp1(crests_x(~isnan(c_new(:,nn)),nn), c_new(~isnan(c_new(:,nn)),nn), x10, 'nearest');
    c_short(:,nn) = fliplr(aa);
end
x10 = (flipud(x10))';
for nn = 1:length(x10); counts(nn) = sum(~isnan(c_short(nn,:))); end
max_id = round(median(find(max(counts)==counts)));
cutoff = max(counts).*.10; ab=abs(counts-max(counts).*.10);
min_diff = min(ab(max_id:end)); for ii = max_id:1:length(x10); if ab(ii) == min_diff; offshore_cutoff = ii; break; end; end
min_diff = min(ab(1:max_id)); for ii = max_id:-1:1; if ab(ii) == min_diff; onshore_cutoff = ii; break; end; end
c_short(1:onshore_cutoff,:)= NaN;
c_short(offshore_cutoff:end,:)=NaN;

Video.crests.t = crests_t;
Video.crests.x = crests_x;
Video.crests.t_for_c = t_slots;
Video.crests.x_for_c = repmat(x10', 1,size(crests_t,2));
Video.crests.c = flipud(c_real);
Video.crests.c_15m_avg = flipud(c_short);
Video.crests.c_25m_avg = flipud(c_long);

end