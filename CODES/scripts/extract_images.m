%% Extract IMAGES

for dd = 1:length(data_files)
    clearvars -except dd *_dir user_email data_files
    cd([data_files(dd).folder '/' data_files(dd).name])

    load([data_files(dd).folder '/' data_files(dd).name '/input_data.mat'])

    for ff = 1:length(flights)
        odir = [flights(ff).folder '/' flights(ff).name];
        oname = [data_files(dd).name '_' flights(ff).name];
        cd(odir) 

        for hh = 1:length(extract_Hz)
            if ~exist(sprintf('images_%iHz', extract_Hz(hh)), 'dir')
                mkdir(sprintf('images_%iHz', extract_Hz(hh)))
            end
            imageDirectory = sprintf('images_%iHz/', extract_Hz(hh));
            load(fullfile(odir, 'Processed_data', 'Inital_coordinates'), 'jpg_id', 'mov_id', 'C')

            
            % Extract images from each video
            for ii = 1:length(mov_id)
                mkdir([imageDirectory char(string(ii))])
                system(['ffmpeg -i ' char(string(C.FileName(mov_id(ii)))) ' -qscale:v 2 -r ' char(string(extract_Hz(hh))) ' ' imageDirectory '' char(string(ii)) '/Frame_%04d.jpg'])
            end
            % Combine images and rename into sequential
            for ii = 1:length(mov_id)
                L = dir(imageDirectory); L([L.isdir] == 1) = []; if ~isempty(L); L = string(extractfield(L, 'name')');end
                Lfull = length(L);
                L = dir([imageDirectory char(string(ii))]); L([L.isdir] == 1) = []; L = string(extractfield(L, 'name')');

                if ii == 1
                    movefile(sprintf([imageDirectory '%d/Frame_*'], ii), imageDirectory)
                else
                    for ll = 1:length(L)
                        if ll < 10
                            id = ['000' char(string(ll))];
                        elseif ll < 100
                            id = ['00' char(string(ll))];
                        elseif ll < 1000
                            id = ['0' char(string(ll))];
                        else
                            id = [char(string(ll))];
                        end

                        movefile(sprintf([imageDirectory '%d/Frame_%s.jpg'], ii,id),sprintf([imageDirectory 'Frame_%s.jpg'], char(string(ll+Lfull))))
                    end
                end  % if ii == 1
            end % for ii = 1:length(mov_id)

            % remove placeholder folders
            for ii = 1:length(mov_id); rmdir(sprintf([imageDirectory '%d'], ii), 's'); end

        end % for hh = 1:length(extract_Hz)

        sendmail(user_email{2}, [oname '- Image Extraction Done'])

    end % for ff = 1:length(flights)
end % for dd = 1:length(data_files)