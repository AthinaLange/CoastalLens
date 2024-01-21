function [scp] = redefine_SCP(scp, In, scpUVd_old)
hGCP=figure(100);clf
imshow(In)
hold on
scatter(scpUVd_old(1), scpUVd_old(2), 50, 'y', 'LineWidth', 3)

xlim([scpUVd_old(1)-50 scpUVd_old(1)+50])
ylim([scpUVd_old(2)-50 scpUVd_old(2)+50])

prev_radius = scp.R;
h=rectangle('position',[scpUVd_old(1)-prev_radius, scpUVd_old(2)-prev_radius, 2*prev_radius, 2*prev_radius],'EdgeColor','r','linewidth',1);

while true
    new_radius = double(string(inputdlg({'Area of Interest Size'}, 'Click Enter with previous radius to finish.',1, {num2str(prev_radius)})));
    if new_radius ~= prev_radius
        delete(h)
        h=rectangle('position',[scpUVd_old(1)-new_radius,scpUVd_old(2)-new_radius,2*new_radius,2*new_radius],'EdgeColor','r','linewidth',1);
        prev_radius = new_radius;
    else
        break;
    end % if new_radius ~= prev_radius
end % while true
scp.R = prev_radius;

% ========================threshold============================================

I_gcp = In(round(scpUVd_old(2)-scp.R):round(scpUVd_old(2)+scp.R), round(scpUVd_old(1)-scp.R):round(scpUVd_old(1)+scp.R), :);
hIN = figure(2);clf
hIN.Position(3)=3*hIN.Position(4);
subplot(121, 'Parent', hIN)
imshow(rgb2gray(I_gcp))
colormap jet
hold on
colorbar; caxis([0 256]);
answer = questdlg('Bright or dark threshold', ...
    'Threshold direction',...
    'bright', 'dark', 'bright');
scp.brightFlag = answer;

ax2 = subplot(122, 'Parent', hIN);

prev_threshold = 100;
switch answer
    case 'bright'
        mask = rgb2gray(I_gcp) > prev_threshold;
    case 'dark'
        mask = rgb2gray(I_gcp) < prev_threshold;
end
[rows, cols] = size(mask);
[y, x] = ndgrid(1:rows, 1:cols);
centroid = mean([x(mask), y(mask)]);
imshow(mask, 'Parent', ax2)
colormap jet
hold on
plot(centroid(1), centroid(2), 'w+', 'MarkerSize', 10);

while true
    new_threshold = double(string(inputdlg({'Threshold'}, 'Click Enter with previous threshold to finish.',1, {num2str(prev_threshold)})));
    if new_threshold ~= prev_threshold
        cla
        switch answer
            case 'bright'
                mask = rgb2gray(I_gcp) > new_threshold;
            case 'dark'
                mask = rgb2gray(I_gcp) < new_threshold;
        end
        if length(x(mask)) == 1
            centroid(1)=x(mask);
        else
            centroid(1) = mean(x(mask));
        end
        if length(y(mask)) == 1
            centroid(2)=y(mask);
        else
            centroid(2) = mean(y(mask));
        end
        imshow(mask, 'Parent', ax2)
        colormap jet
        hold on
        plot(centroid(1), centroid(2), 'w+', 'MarkerSize', 10);
        prev_threshold = new_threshold;
    else
        break;
    end % if new_threshold ~= prev_threshold
end % while true
scp.T = prev_threshold;
close(hIN)
close(hGCP)

end
