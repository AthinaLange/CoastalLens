function save_rectified_image(oname, save_dir, Products)
%   save_rectified_image saves the RGB images in Products as pngs.
%% Syntax
% save_rectified_image(oname, save_dir, Products)
%
%% Description
%   Args:
%           oname (string) : file name - typically 'YYYYMMDD_Location_Flight_#'
%           save_dir (string) : folder location where rectified images will be saved
%           Products (structure) : Products folder that contains uint8 images to be saved
%                       type (string) : 'Grid', 'xTransect', 'yTransect'
%                       frameRate (double) : frame rate of product (Hz)
%                       xlim (double): [1 x 2] cross-shore limits of grid (+ is offshore of origin) (m)
%                       ylim (double) : [1 x 2] along-shore limits of grid (+ is to the right of origin looking offshore) (m)
%                       dx (double) : Cross-shore resolution (m)
%                       dy (double) : Along-shore resolution (m)
%                       x (double): Cross-shore distance from origin (+ is offshore of origin) (m)
%                       y (double): Along-shore distance from origin (+ is to the right of the origin looking offshore) (m)
%                       t (datetime array) : [1 x m] datetime of images at given extraction rates in UTC
%                       Irgb_2d (uint8 image) : [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim
%
%   Returns:
%
%% Example 1
%
% oname = '20211215_Torrey_Flight_04'
% odir = fullfile(global_dir, 'DATA', '20211215_Torrey', 'Flight_04')
% save_dir = fullfile(odir, 'Rectified_images')
% load(fullfile(odir, 'Processed_data', [oname '_Products.mat']), 'Products)
% save_rectified_image(oname, save_dir, Products)
%
%% Citation Info
% github.com/AthinaLange/UAV_automated_rectification
% Jan 2024;

%% Options
assert(isa(oname, 'string'), 'Error (combine_images): data_files must be a structure.')
assert((isfield(data_files, 'folder') && isfield(data_files, 'name')), 'Error (combine_images): data_files must have fields .folder and .name.')
assert(isa(options.imageDirectory, 'char'), 'Error (combine_images): imageDirectory must be a string.')
assert(isfolder(options.imageDirectory),'Error (combine_images): imageDirectory must be the path to a folder.');

%% Create Products
for pp = 1:length(Products)
    if contains(Products(pp).type, 'Grid')
        mkdir(fullfile(save_dir, 'Grid'))
        for tt = 1:size(Products(pp).Irgb_2d,1) % go through all time steps
            image = squeeze(Products(pp).Irgb_2d(tt,:,:,:));
            if Products(pp).frameRate > 1
                dt = char(string(rem(tt,Products(pp).frameRate)));
                 t = [char(strrep(string(Products(pp).t(tt)),' ','_')) '_' dt 'ms'];
            else
                t = char(strrep(string(Products(pp).t(tt)),' ','_'));
            end

            xlim = string(Products(pp).xlim); xlim=char(append(xlim(1), '_', xlim(2)));
            ylim = string(Products(pp).ylim); ylim=char(append(ylim(1), '_', ylim(2)));
            dx = char(string(Products(pp).dx));
            dy = char(string(Products(pp).dy));
            imwrite(image,fullfile(fullfile(save_dir, 'Grid'), ...
                [oname '_' Products(pp).type '_datetime_' t '_xlim_' xlim 'm_ylim_' ylim ...
                'm_dx_' dx 'm_dy_' dy 'm.png']));
        end

    elseif contains(Products(pp).type, 'xTransect')
            t = char(strrep(string(Products(pp).t(tt)),' ','_'));
            frameRate = char(string(Products(pp).frameRate));
            xlim = string(Products(pp).xlim); xlim=char(append(xlim(1), '_', xlim(2)));
            y = char(string(Products(pp).y));
            dx = char(string(Products(pp).dx));
        imwrite(Products(pp).Irgb_2d,fullfile(save_dir, [oname '_' Products(pp).type '_datetime_' t '_frameRate_' frameRate 'Hz_xlim_' xlim 'm_y_' y 'm_dx_' dx 'm.png']));

    elseif contains(Products(pp).type, 'yTransect')
            t = char(strrep(string(Products(pp).t(tt)),' ','_'));
            frameRate = char(string(Products(pp).frameRate));
            x = char(string(Products(pp).x));
            ylim = string(Products(pp).ylim); ylim=char(append(ylim(1), '_', ylim(2)));
            dy = char(string(Products(pp).dy));
        imwrite(Products(pp).Irgb_2d,fullfile(save_dir, [oname '_' Products(pp).type '_datetime_' t '_frameRate_' frameRate 'Hz_ylim_' ylim 'm_x_' x 'm_dy_' dy 'm.png']));
    end

end
end