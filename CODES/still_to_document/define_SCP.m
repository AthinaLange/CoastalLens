function [scp] = define_SCP(I, image_gcp, intrinsics_CIRN)
%
%   Define SCP radius and threshold parameters for image gcps.
%
close all
hFig = figure(1);clf
imshow(I)
hold on
scatter(image_gcp(:,1), image_gcp(:,2), 50, 'y', 'LineWidth', 3)
for ii = 1:length(image_gcp)
    text(image_gcp(ii,1)+50, image_gcp(ii,2)-50, ['GCP ' char(string(ii))], 'FontSize', 14, 'BackgroundColor', 'w')
end
answer_z = questdlg('Are elevation values in GCP coordinates file?', ...
    'SCP Elevation',...
    'Yes', 'No', 'Yes');
switch answer_z
    case 'Yes'
        disp('Load in target GCP coordinates file.')
        disp('For CPG: Should be under the individual day. gps_northings.txt')
        [temp_file, temp_file_path] = uigetfile({'*.txt'}, 'GCP Targets');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*
        for gg = 1:length(gps_northings)
            gcp_options(gg,:) = sprintf('%i - %.2fm', gg, gps_northings(gg,4));
        end
end

for gg = 1:length(image_gcp)
    %% ========================radius============================================
    %                           - Determine search area around bright or dark target.
    %  =====================================================================
    hFig
    scp(gg).UVdo = image_gcp(gg,:);
    scp(gg).num = gg;

    xlim([image_gcp(gg,1)-intrinsics_CIRN(1)/10 image_gcp(gg,1)+intrinsics_CIRN(1)/10])
    ylim([image_gcp(gg,2)-intrinsics_CIRN(2)/10 image_gcp(gg,2)+intrinsics_CIRN(2)/10])

    prev_radius = 50;
    h=rectangle('position',[image_gcp(gg,1)-prev_radius,image_gcp(gg,2)-prev_radius,2*prev_radius,2*prev_radius],'EdgeColor','r','linewidth',1);

    while true
        new_radius = double(string(inputdlg({'Area of Interest Size'}, 'Click Enter with previous radius to finish.',1, {num2str(prev_radius)})));
        if new_radius ~= prev_radius
            delete(h)
            h=rectangle('position',[image_gcp(gg,1)-new_radius,image_gcp(gg,2)-new_radius,2*new_radius,2*new_radius],'EdgeColor','r','linewidth',1);
            prev_radius = new_radius;
        else
            break;
        end % if new_radius ~= prev_radius
    end % while true
    scp(gg).R = prev_radius;

    %% ========================threshold============================================
    %                           - Determine threshold value for bright (dark) point - used for tracking through images
    %  =====================================================================

    I_gcp = I(round(scp(gg).UVdo(2)-scp(gg).R):round(scp(gg).UVdo(2)+scp(gg).R), round(scp(gg).UVdo(1)-scp(gg).R):round(scp(gg).UVdo(1)+scp(gg).R), :);
    hIN = figure(2);clf
    hIN.Position(3)=3*hIN.Position(4);
    subplot(121, 'Parent', hIN)
    imshow(rgb2gray(I_gcp))
    colormap jet
    hold on
    cb = colorbar; clim([0 256]);
    answer = questdlg('Bright or dark threshold', ...
        'Threshold direction',...
        'bright', 'dark', 'bright');
    scp(gg).brightFlag = answer;

   
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
    ax2=subplot(122, 'Parent', hIN);
    imshow(mask, 'Parent', ax2)
    colormap jet
    hold on
    plot(centroid(1), centroid(2), 'w+', 'MarkerSize', 10);

    while true
        new_threshold = double(string(inputdlg({'Threshold'}, 'Click Enter with previous threshold to finish.',1, {num2str(prev_threshold)})));
        if new_threshold ~= prev_threshold
            cla(ax2)
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
    scp(gg).T = prev_threshold;
    close(hIN)
    %% ========================elevation============================================
    %                           - Pull corresponding elevation value
    %  =====================================================================
    switch answer_z
        case 'Yes'
            [ind_gcp,~] = listdlg('ListString', gcp_options, 'SelectionMode','single', 'InitialValue',gg, 'PromptString', {'What ground control points' 'did you use?'});
            scp(gg).z = gps_northings(ind_gcp, 4);
        case 'No'
            scp(gg).z = double(string(inputdlg({'Elevation'})));
    end

end % for gg = 1:length(image_gcp)
