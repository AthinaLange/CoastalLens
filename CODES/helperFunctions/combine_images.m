function combine_images(data_files, varargin)
% combine_images(data_files, imageDirectory)
% COMBINE_IMAGES  Combine image sequence from multiple folders
%     combine_images(data_files) Structure of data files - requires data_files.folder and data_files.name
%     combine_images(data_files, imageDirectory) ImageDirectory where files should be moved to
%
%
% 
%
%
% (c) Athina Lange, Coastal Processes Group, Scripps Institution of Oceanography - Sept 2023


%%
options.imageDirectory = fullfile(data_files(1).folder); % frameRate in Hz (default = 2Hz)

options = parseOptions( options , varargin );


%%
    for dd = 1:length(data_files)   
           folder_name = split(data_files(dd).name, '.'); folder_name = string(folder_name{1});
           folder_name = fullfile(data_files(dd).folder, char(folder_name));
            if dd == 1
                movefile(fullfile(folder_name, 'Frame_*'), options.imageDirectory)
            else
                L = imageDatastore(options.imageDirectory);
                Lfull = length(L.Files);
                
                L = imageDatastore(folder_name);

                % rename files to be sequential based on total image frames
                for ll = 1: length(L.Files)
                    if ll < 10
                        id = ['0000' char(string(ll))];
                    elseif ll < 100
                        id = ['000' char(string(ll))];
                    elseif ll < 1000
                        id = ['00' char(string(ll))];
                    elseif ll < 10000
                        id = ['0' char(string(ll))];
                    else
                        id = [char(string(ll))];
                    end

                     if ll+Lfull < 10
                        id_full = ['0000' char(string(ll+Lfull))];
                    elseif ll+Lfull < 100
                        id_full = ['000' char(string(ll+Lfull))];
                    elseif ll+Lfull < 1000
                        id_full = ['00' char(string(ll+Lfull))];
                    elseif ll+Lfull < 10000
                        id_full = ['0' char(string(ll+Lfull))];
                    else
                        id_full = [char(string(ll+Lfull))];
                    end

                    movefile(fullfile(folder_name, ['Frame_' id '.jpg']), fullfile(options.imageDirectory, ['Frame_' id_full '.jpg']))
            end % for ll = 1:length(L)
        end  % if dd == 1
        % remove placeholder folders
        rmdir(folder_name, 's')
    end % for dd = 1:length(data_files) 
  
end