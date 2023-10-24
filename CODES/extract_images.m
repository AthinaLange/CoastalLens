%% extract_images
%
% Repeat for each day + flight
%
%   For each extraction frame rate:
%           - make Hz directory for images
%           - for every movie to be extracted: extract images from video at extraction frame rate using ffmpeg (into seperate folder intially)
%           - move images from movie folders into group folder and rename sequentially
%
%  Send email that image extraction complete
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023

%%
% repeat for each day
for dd = 1: length(data_files)
    clearvars -except dd *_dir user_email data_files
    cd(fullfile(data_files(dd).folder, data_files(dd).name))

    load(fullfile(data_files(dd).folder, data_files(dd).name, 'input_data.mat'))

    % repeat for each flight
    for ff = 1: length(flights)
        odir = fullfile(flights(ff).folder, flights(ff).name);
        oname = [data_files(dd).name '_' flights(ff).name];
        cd(odir) 

        % repeat for each extracted frame rate
        for hh = 1 : length(extract_Hz)
            if ~exist(sprintf('images_%iHz', extract_Hz(hh)), 'dir')
                mkdir(sprintf('images_%iHz', extract_Hz(hh)))
            end
            imageDirectory = sprintf('images_%iHz', extract_Hz(hh));
            load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'jpg_id', 'mov_id', 'C')

            % repeat for each video
            for ii = 1 : length(mov_id)
                mkdir(fullfile(imageDirectory, char(string(ii))))
                system(['ffmpeg -i ' char(string(C.FileName(mov_id(ii)))) ' -qscale:v 2 -r ' char(string(extract_Hz(hh))) ' ' fullfile(imageDirectory, char(string(ii)), 'Frame_%04d.jpg')])
            end
            % Combine images and rename into sequential
            for ii = 1:length(mov_id)
                L = dir(imageDirectory); L([L.isdir] == 1) = []; if ~isempty(L); L = string(extractfield(L, 'name')');end;  if ~isempty(L); L(L=='.DS_Store')=[];end
                Lfull = length(L);
                L = dir(fullfile(imageDirectory, char(string(ii)))); L([L.isdir] == 1) = []; L = string(extractfield(L, 'name')');  if ~isempty(L); L(L=='.DS_Store')=[];end

                if ii == 1
                    movefile(fullfile(imageDirectory, char(string(ii)), 'Frame_*'), imageDirectory)
                else
                    for ll = 1: length(L)
                        if ll < 10
                            id = ['000' char(string(ll))];
                        elseif ll < 100
                            id = ['00' char(string(ll))];
                        elseif ll < 1000
                            id = ['0' char(string(ll))];
                        else
                            id = [char(string(ll))];
                        end

                        movefile(fullfile(imageDirectory, char(string(ii)), ['Frame_' id '.jpg']), fullfile(imageDirectory, ['Frame_' char(string(ll+Lfull)) '.jpg']))
                    end
                end  % if ii == 1
            end % for ii = 1:length(mov_id)

            % remove placeholder folders
            for ii = 1:length(mov_id); rmdir(fullfile(imageDirectory, char(string(ii))), 's'); end

        end % for hh = 1:length(extract_Hz)
    
        if exist('user_email', 'var')
            sendmail(user_email{2}, [oname '- Image Extraction Done'])
        end
    end % for ff = 1:length(flights)
end % for dd = 1:length(data_files)