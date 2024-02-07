function [Product] = define_grid(origin_grid)
%   define_grid returns structure with dimensions needed for a cBathy-type grid.
%% Syntax
% [Product] = define_grid([lat lon angle])
%
%% Description 
% 
%   Args:
%           origin_grid (double) : [1 x 3 array] origin_grid definition [Latitude, Longitude, Angle]
%
%   Returns:
%           Products (structure) : 
%                               - productType : 'cBathy'
%                               - type : 'Grid'
%                               - frameRate : frame rate to process data (Hz)
%                               - lat : latitude of origin grid
%                               - lon: longitude of origin grid
%                               - angle: shorenormal angle of origid grid
%                               - xlim : cross-shore limits of grid (pos is offshore of origin) (m)
%                               - ylim : along-shore limits of grid (pos is to the right of origin looking offshore) (m)
%                               - dx : Cross-shore resolution (m)
%                               - dy : Along-shore resolution (m)
%                               - z : Elevation - can be empty, assigned to tide level, or array of DEM values (NAVD88 m)
%               
% Angle: Shorenormal angle of the locally defined grid (CW from North)
%
%% Citation Info 
% github.com/AthinaLange/UAV_automated_rectification
% Nov 2023; 

%%
assert(isa(origin_grid, 'double'), 'Error (define_grid): origin_grid must be an array of doubles.')
assert(length(origin_grid)==3, 'Error (define_grid): origin_grid must contain 3 values.')
%%
Product = struct('productType',[], 'type',[],  'frameRate',[],  'lat', [], 'lon',[],  'angle',[], 'xlim',[],  'ylim',[],  'dx',[],  'dy', [], 'x', [], 'y',[],  'z',[]);

Product.productType = 'cBathy';
Product.type = 'Grid';

Product.lat = origin_grid(1);
Product.lon = origin_grid(2);
Product.angle = origin_grid(3);

info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (m from Origin)', 'Onshore cross-shore extent (m from Origin, + if offshore)', ...
    'Southern Alongshore extent (m from Origin)', 'Northern Alongshore extent (m from Origin)',...
    'dx', 'dy', 'z elevation (tide level in relevant datum)'}, 'Grid Coordinates')));
answer = questdlg('Do you want to include a DEM?', 'DEM file', 'Yes', 'No', 'Yes');


info = abs(info); % making everything +meters from origin

% check that there's a value in all the required fields
if find(isnan(info)) ~= 8
    disp('Please fill out all boxes (except z elevation if necessary)')
    info = double(string(inputdlg({'Frame Rate (Hz)', 'Offshore cross-shore extent (+m from Origin)', 'Onshore cross-shore extent (+m from Origin)', ...
        'Southern Alongshore extent (+m from Origin)', 'Northern Alongshore extent (+m from Origin)',...
        'dx', 'dy', 'z elevation (tide level in relevant datum)'}, 'Grid Coordinates')));
    info(1:7) = abs(info(1:7)); % making everything +meters from origin
end % if find(isnan(info)) ~= 8

if info(1) > 30
    disp('Maximum frame rate is 30Hz - Please choose a different frame rate.')
    info(1) = double(string(inputdlg({'Frame Rate (Hz)'})));
end % if info(1) > 30
Product.frameRate = info(1);

Product.xlim = [info(2) -info(3)]; % offshore limit is negative meters
if origin_grid(3) < 180 % East Coast
    Product.ylim = [-info(5) info(4)]; % -north +south
elseif origin_grid(3) > 180 % West Coast
    Product.ylim = [-info(4) info(5)]; % -south +north
end % if origin_grid(3) < 180 % East Coast
Product.dx = info(6);
Product.dy = info(7);
switch answer
    case 'No'
        Product.z = info(8);
    case 'Yes'
        X_line = Product.xlim(1):-Product.dx:Product.xlim(2);
        Y_line = Product.ylim(1):Product.dy:Product.ylim(2);
        [X,Y] = meshgrid(X_line,Y_line);

        disp('Load in DEM file')
        [temp_file, temp_file_path] = uigetfile(pwd, 'DEM file');
        load(fullfile(temp_file_path, temp_file)); clear temp_file*
        answer2 = questdlg('Is this a global DEM file or local?', 'DEM file', 'Global', 'Local', 'Local');
        % check that local coordinates
        DEM_scale = (floor(log(abs([DEM.y]))./log(10))); DEM_scale(isinf(DEM_scale)) = []; DEM_scale = nanmean(DEM_scale);
        grid_scale = nanmean(floor(log(abs([Product.ylim]))./log(10)));
        if DEM_scale ~= grid_scale
            answer2 = 'Global';
        end % if DEM_scale ~= grid_scale
        switch answer2
            case 'Global' % assumes DEM in UTM coordinates
                [origin_grid(1), origin_grid(2), ~] = ll_to_utm(origin_grid(1), origin_grid(2));

                for ii = 1:length(DEM)
                    % Translate from origin
                    ep=DEM(ii).x-origin_grid(1);
                    np=DEM(ii).y-origin_grid(2);

                    % Rotation
                    DEM(ii).x=ep.*cosd(origin_grid(3))+np.*sind(origin_grid(3));
                    DEM(ii).y=np.*cosd(origin_grid(3))-ep.*sind(origin_grid(3));

                    Z_line(ii,:) = interp1(DEM(ii).x, DEM(ii).z, X_line);
                end
            case 'Local' % assumes same grid origin and orientation
                for ii = 1:length(DEM)
                    Z_line(ii,:) = interp1(DEM(ii).x, DEM(ii).z, X_line);
                end %  for ii = 1:length(DEM)
        end % switch answer2
        Z = interp2(X_line, [DEM.y], Z_line, X, Y);
        tide_level = info(8)*ones(size(X,1), size(X,2));
        aa(:,:,1)=Z;
        aa(:,:,2)=tide_level;
        Product.z = max(aa,[],3);
end % switch answer
end